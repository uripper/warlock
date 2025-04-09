defmodule Witch do
    # Attempts to locate an executable in the system PATH. If an exact match isn’t found,
  # performs fuzzy matching against all executables in the PATH.
  def witch(command, verbose, sensitivity, algorithm) do
    if verbose, do: IO.puts("Searching for '#{command}' in PATH...")

    if path = System.find_executable(command) do
      if verbose, do: IO.puts("Exact match found: #{path}")
      IO.puts(path)
      path
    else
      if verbose, do: IO.puts("Exact match not found. Gathering all executables from PATH...")
      executables = get_all_executables(verbose)

      if verbose,
        do:
          IO.puts("Calculating similarities for fuzzy matching (sensitivity = #{sensitivity})...")

      matches =
        executables
        |> Enum.map(fn exe -> {exe, Similaritysearch.similarity(command, exe, sensitivity, verbose, algorithm)} end)
        |> Enum.filter(fn {_exe, sim} -> sim >= 0.6 end)
        |> Enum.sort_by(fn {_exe, sim} -> -sim end)
        |> Enum.take(5)

      if matches == [] do
        IO.puts("Command not found and no close matches.")
      else
        IO.puts("\nCommand '#{command}' not found. Close matches:\n")
        Output.print_suggestions_table(matches, command, verbose)
      end

      nil
    end
  end

  # Returns a list of all filenames found in directories specified by the PATH.
  defp get_all_executables(verbose) do
    path_env = System.get_env("PATH") || ""
    separator = if match?({:win32, _}, :os.type()), do: ";", else: ":"

    executables =
      path_env
      |> String.split(separator)
      |> Enum.flat_map(fn dir ->
        case File.ls(dir) do
          {:ok, files} ->
            if verbose, do: IO.puts("Found #{length(files)} files in #{dir}")
            files

          _ ->
            if verbose, do: IO.puts("Could not list files in #{dir}")
            []
        end
      end)
      |> Enum.uniq()

    if verbose, do: IO.puts("Total unique executables found: #{length(executables)}")
    executables
  end
end
