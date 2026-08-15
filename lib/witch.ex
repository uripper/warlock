defmodule Witch do
  @moduledoc """
  A command-line utility for finding executables in the system PATH.
  """

  import Bitwise, only: [band: 2]

  @wsl_drive_path ~r{\A/mnt/[a-z](?:/|\z)}i
  @wsl_command_extensions ~w(.bat .bash .cmd .com .exe .fish .js .pl .py .rb .sh .zsh)
  @windows_default_extensions ~w(.bat .cmd .com .exe)
  @candidate_chunks_per_scheduler 1

  @type search_options :: %{
          algorithm: :jaro_winkler | :levenshtein,
          ignore_patterns: [binary()],
          ignored_directories: [binary()],
          num_matches: pos_integer(),
          sensitivity: float(),
          threshold: float(),
          verbose: boolean()
        }

  @spec witch(binary(), search_options()) :: nil | binary()
  def witch(command, search_options) do
    log_search(command, search_options)

    case System.find_executable(command) do
      nil -> find_suggestions(command, search_options)
      path -> print_exact_match(path, search_options.verbose)
    end
  end

  defp log_search(_, %{verbose: false}), do: :ok

  defp log_search(command, search_options) do
    IO.puts("Searching for '#{command}' in PATH...")

    IO.puts(
      "Sensitivity: #{search_options.sensitivity}, Algorithm: #{search_options.algorithm}, " <>
        "Threshold: #{search_options.threshold}"
    )

    IO.puts(
      "Ignoring: #{Enum.join(search_options.ignore_patterns, ", ")}, " <>
        "Ignored Directories: #{Enum.join(search_options.ignored_directories, ", ")}"
    )
  end

  defp print_exact_match(path, verbose) do
    log_if_verbose("Exact match found: #{path}", verbose)
    IO.puts(path)
    path
  end

  defp find_suggestions(command, search_options) do
    log_if_verbose(
      "Exact match not found. Gathering all executables from PATH...",
      search_options.verbose
    )

    executables =
      get_all_executables(
        search_options.verbose,
        search_options.ignore_patterns,
        search_options.ignored_directories
      )

    matches = find_matches(executables, command, search_options)
    print_suggestions(matches, command, search_options.verbose)
    nil
  end

  defp print_suggestions([], _, _), do: IO.puts("Command not found and no close matches.")

  defp print_suggestions(matches, command, verbose) do
    IO.puts("\nCommand '#{command}' not found. Close matches:\n")
    Output.print_suggestions_table(matches, command, verbose)
  end

  defp log_if_verbose(message, true), do: IO.puts(message)
  defp log_if_verbose(_, false), do: :ok

  defp collect_from_dir(dir, ignore_patterns, ignored_dirs, platform) do
    if ignore_dir?(dir, ignored_dirs) do
      []
    else
      case File.ls(dir) do
        {:ok, files} -> collect_executables(files, dir, ignore_patterns, platform)
        _ -> []
      end
    end
  end

  defp collect_executables(files, directory, ignore_patterns, platform) do
    directory_kind = directory_kind(directory, platform)

    Enum.reduce(files, [], fn file, executables ->
      if ignore_file?(file, ignore_patterns) or
           not command_extension?(file, directory_kind) do
        executables
      else
        path = Path.join(directory, file)

        [{file, {path, platform, directory_kind}} | executables]
      end
    end)
  end

  defp executable_file?(_, :windows, _), do: true
  defp executable_file?(_, :unix, :wsl_windows), do: true

  defp executable_file?(path, :unix, :unix) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> band(mode, 0o111) != 0
      _ -> false
    end
  end

  defp directory_kind(_, :windows), do: {:windows, windows_command_extensions()}

  defp directory_kind(directory, :unix) do
    if Regex.match?(@wsl_drive_path, directory), do: :wsl_windows, else: :unix
  end

  defp command_extension?(_, :unix), do: true

  defp command_extension?(file, :wsl_windows) do
    extension =
      file
      |> Path.extname()
      |> String.downcase()

    extension == "" or extension in @wsl_command_extensions
  end

  defp command_extension?(file, {:windows, extensions}) do
    file
    |> Path.extname()
    |> String.downcase()
    |> then(&MapSet.member?(extensions, &1))
  end

  defp windows_command_extensions do
    "PATHEXT"
    |> System.get_env(Enum.join(@windows_default_extensions, ";"))
    |> String.split(";", trim: true)
    |> Enum.map(&String.downcase/1)
    |> MapSet.new()
  end

  # ----------------------------------------------------------------------------
  # ignore_dir?/2:
  #
  # This implementation converts both the directory path and the ignore pattern
  # to upper case so that the match is case-insensitive. Then it checks if the
  # directory path contains the ignored substring.
  # ----------------------------------------------------------------------------
  defp ignore_dir?(dir, ignored_dirs) do
    dir_up = String.upcase(dir)

    Enum.any?(ignored_dirs, fn pattern ->
      String.contains?(dir_up, pattern)
    end)
  end

  defp ignore_file?(file, patterns) do
    Enum.any?(patterns, &String.contains?(file, &1))
  end

  defp find_matches(executables, command, search_options) do
    concurrency = System.schedulers_online()
    chunk_size = candidate_chunk_size(length(executables), concurrency)
    prepared_query = Similaritysearch.prepare_query(command, search_options.algorithm)

    executables
    |> Enum.chunk_every(chunk_size)
    |> parallel_flat_map(
      &score_chunk(&1, prepared_query, search_options),
      concurrency
    )
    |> take_best(search_options.num_matches)
  end

  defp candidate_chunk_size(candidate_count, concurrency) do
    target_chunks = concurrency * @candidate_chunks_per_scheduler
    max(div(candidate_count + target_chunks - 1, target_chunks), 1)
  end

  defp score_chunk(executables, prepared_query, search_options) do
    executables
    |> Enum.reduce([], &score_candidate(&1, &2, prepared_query, search_options))
    |> take_best(search_options.num_matches)
  end

  defp score_candidate({name, paths}, matches, prepared_query, search_options) do
    case Similaritysearch.score_candidate(
           prepared_query,
           name,
           search_options.sensitivity,
           search_options.threshold
         ) do
      {:ok, similarity} ->
        case first_executable_path(paths) do
          nil -> matches
          path -> [{name, path, similarity} | matches]
        end

      :below_threshold ->
        matches
    end
  end

  defp first_executable_path(paths) do
    # Candidate paths are stored in reverse PATH order, so each executable
    # replacement leaves the earliest executable path as the final result.
    Enum.reduce(paths, nil, fn {path, platform, directory_kind}, first_path ->
      if executable_file?(path, platform, directory_kind), do: path, else: first_path
    end)
  end

  defp take_best(matches, limit) do
    matches
    |> Enum.sort_by(&match_sort_key/1)
    |> Enum.take(limit)
  end

  defp match_sort_key({executable, _, similarity}), do: {-similarity, executable}

  # ===============================================================
  # get_all_executables/3
  #
  # Returns executable files found in directories specified by PATH,
  # excluding ignored directories and filenames. Directories are read
  # concurrently while their results retain PATH precedence.
  # ===============================================================
  defp get_all_executables(verbose, ignore_patterns, ignored_dirs) do
    path = System.get_env("PATH", "")
    platform = platform()
    normalized_ignored_dirs = Enum.map(ignored_dirs, &String.upcase/1)

    separator =
      if platform == :windows, do: ";", else: ":"

    executables =
      path
      |> String.split(separator, trim: true)
      |> Enum.uniq()
      |> parallel_flat_map(
        &collect_from_dir(
          &1,
          ignore_patterns,
          normalized_ignored_dirs,
          platform
        ),
        directory_concurrency(),
        true
      )
      |> group_candidates()

    if verbose, do: IO.puts("Total unique executables found: #{length(executables)}")
    executables
  end

  defp group_candidates(candidates) do
    candidates
    |> Enum.reduce(%{}, fn {name, path}, grouped_candidates ->
      Map.update(grouped_candidates, name, [path], &[path | &1])
    end)
    |> Map.to_list()
  end

  defp platform do
    if match?({:win32, _}, :os.type()), do: :windows, else: :unix
  end

  defp directory_concurrency do
    schedulers = System.schedulers_online()
    min(schedulers * 2, 32)
  end

  defp parallel_flat_map(enumerable, mapper, max_concurrency, ordered \\ false) do
    enumerable
    |> Task.async_stream(mapper,
      max_concurrency: max_concurrency,
      ordered: ordered,
      timeout: :infinity
    )
    |> Enum.flat_map(&unwrap_task_result!/1)
  end

  defp unwrap_task_result!({:ok, items}), do: items
  defp unwrap_task_result!({:exit, reason}), do: exit(reason)
end
