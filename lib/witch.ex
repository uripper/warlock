defmodule Witch do
  # ===============================================================
  # Main function: Searches for a command, first looking for an exact match.
  # If not found, performs fuzzy matching against executables in PATH,
  # excluding files in ignored directories and files matching ignore patterns.
  # ===============================================================
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

  # ===============================================================
  # get_all_executables/3
  #
  # Returns a list of filenames found in directories specified by the PATH,
  # excluding directories matching any pattern in ignoredir and files that
  # include any of the ignore patterns.
  # ===============================================================
  defp get_all_executables(verbose, ignore, ignoredir) do
    path_env = System.get_env("PATH") || ""
    separator = if match?({:win32, _}, :os.type()), do: ";", else: ":"

    executables =
      path_env
      |> String.split(separator)
      |> Enum.flat_map(fn dir ->
        # Skip this directory if it should be ignored
        if Enum.any?(ignoredir, fn pattern ->
             Regex.match?(~r/^#{Regex.escape(pattern)}$/, dir)
           end) do
          []
        else
          case File.ls(dir) do
            {:ok, files} ->
              # Filter out files that match the ignore patterns.
              filtered_files =
                files
                |> Enum.reject(fn file ->
                  Enum.any?(ignore, fn ignore_pattern ->
                    String.contains?(file, ignore_pattern)
                  end)
                end)

              filtered_files

            _ ->
              []
          end
        end
      end)
      |> Enum.uniq()

    if verbose, do: IO.puts("Total unique executables found: #{length(executables)}")
    executables
  end
end
