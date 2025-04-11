defmodule Witch do
  @moduledoc """
  A command-line utility for finding executables in the system PATH.
  """
  @spec witch(
          nil | binary(),
          boolean(),
          float(),
          :jaro_winkler | :levenshtein,
          float(),
          pos_integer(),
          list(binary()),
          list(binary())
        ) :: nil | binary()
  def witch(
        command,
        verbose,
        sensitivity,
        algorithm,
        threshold,
        num_matches,
        ignore,
        ignoredir
      ) do
    if verbose do
      IO.puts("Searching for '#{command}' in PATH...")
      IO.puts("Sensitivity: #{sensitivity}, Algorithm: #{algorithm}, Threshold: #{threshold}")

      IO.puts(
        "Ignoring: #{Enum.join(ignore, ", ")}, Ignored Directories: #{Enum.join(ignoredir, ", ")}"
      )
    end

    # Check if an exact match exists
    if path = System.find_executable(command) do
      if verbose, do: IO.puts("Exact match found: #{path}")
      IO.puts(path)
      path
    else
      if verbose, do: IO.puts("Exact match not found. Gathering all executables from PATH...")

      # Gather executables with filtering applied
      executables = get_all_executables(verbose, ignore, ignoredir)

      matches =
        executables
        |> Enum.map(fn exe ->
          {exe, Similaritysearch.similarity(command, exe, sensitivity, verbose, algorithm)}
        end)
        |> Enum.filter(fn {_exe, sim} -> sim >= threshold end)
        |> Enum.sort_by(fn {_exe, sim} -> -sim end)
        |> Enum.take(num_matches)

      if matches == [] do
        IO.puts("Command not found and no close matches.")
      else
        IO.puts("\nCommand '#{command}' not found. Close matches:\n")
        Output.print_suggestions_table(matches, command, verbose)
      end

      nil
    end
  end

  defp collect_from_dir(dir, ignore_patterns, ignored_dirs) do
    if ignore_dir?(dir, ignored_dirs) do
      []
    else
      case File.ls(dir) do
        {:ok, files} -> Enum.reject(files, &ignore_file?(&1, ignore_patterns))
        _error -> []
      end
    end
  end

  defp ignore_dir?(dir, ignored_dirs) do
    Enum.any?(ignored_dirs, &Regex.match?(~r/^#{Regex.escape(&1)}$/, dir))
  end

  defp ignore_file?(file, patterns) do
    Enum.any?(patterns, &String.contains?(file, &1))
  end

  # ===============================================================
  # get_all_executables/3
  #
  # Returns a list of filenames found in directories specified by the PATH,
  # excluding directories matching any pattern in ignoredir and files that
  # include any of the ignore patterns.
  # ===============================================================
  defp get_all_executables(verbose, ignore_patterns, ignored_dirs) do
    separator =
      if match?({:win32, _}, :os.type()), do: ";", else: ":"

    executables =
      System.get_env("PATH", "")
      |> String.split(separator, trim: true)
      |> Enum.flat_map(&collect_from_dir(&1, ignore_patterns, ignored_dirs))
      |> Enum.uniq()

    if verbose, do: IO.puts("Total unique executables found: #{length(executables)}")
    executables
  end
end
