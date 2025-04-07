defmodule Warlock do
  @moduledoc """
  A smarter 'which' command with fuzzy matching.

  Usage:
      warlock <command>
  """

  @ansi_green IO.ANSI.green()
  @ansi_red IO.ANSI.red()
  @ansi_magenta IO.ANSI.magenta()
  @ansi_reset IO.ANSI.reset()

  # Public entry point called by the escript runtime.
  def main(args) do
    case args do
      [command] ->
        witch(command)
      _ ->
        IO.puts("Usage: warlock <command>")
    end
  end

  # Attempts to locate an executable in the system PATH. If an exact match isn’t found,
  # performs fuzzy matching against all executables in the PATH.
  def witch(command) do
    if (path = System.find_executable(command)) do
      IO.puts(path)
      path
    else
      executables = get_all_executables()
      matches =
        executables
        |> Enum.map(fn exe -> {exe, similarity(command, exe)} end)
        |> Enum.filter(fn {_exe, sim} -> sim >= 0.6 end)
        |> Enum.sort_by(fn {_exe, sim} -> -sim end)
        |> Enum.take(5)

      if matches == [] do
        IO.puts("Command not found and no close matches.")
      else
        IO.puts("\nCommand '#{command}' not found. Close matches:\n")
        print_suggestions_table(matches, command)
      end

      nil
    end
  end

  # Returns a list of all filenames found in directories specified by the PATH.
  defp get_all_executables do
    # Get the PATH environment variable (or empty string if not set)
    path_env = System.get_env("PATH") || ""
    # Choose the separator based on the OS type: ";" on Windows, ":" otherwise.
    separator = if match?({:win32, _}, :os.type()), do: ";", else: ":"
    path_env
    |> String.split(separator)
    |> Enum.flat_map(fn dir ->
      case File.ls(dir) do
        {:ok, files} -> files
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  # Prints a formatted table of suggestions.
  # Each row shows the suggested command (with differences highlighted) and its full path.
  defp print_suggestions_table(matches, command) do
    cmd_width = 20
    path_width = 50

    # Filter out any suggestions for which the executable isn’t found.
    valid_matches =
      matches
      |> Enum.filter(fn {suggestion, _sim} -> System.find_executable(suggestion) != nil end)

    if valid_matches == [] do
      IO.puts("Command not found and no close matches.")
    else
      header =
        pad_string("Suggested Command", cmd_width) <>
          " | " <> pad_string("Location", path_width)
      IO.puts(header)
      IO.puts(String.duplicate("-", cmd_width + path_width + 3))

      Enum.each(valid_matches, fn {suggestion, _sim} ->
        highlighted = highlight_differences(command, suggestion)
        suggestion_path = System.find_executable(suggestion)
        line =
          pad_string(highlighted, cmd_width) <>
            " | " <> pad_string(suggestion_path, path_width)
        IO.puts(line)
      end)
    end
  end


  # Pads the given text with spaces so that its visible width is at least `width`.
  # (ANSI escape codes are ignored for width calculation.)
  defp pad_string(text, width) do
    visible = strip_ansi(text)
    pad = max(width - String.length(visible), 0)
    text <> String.duplicate(" ", pad)
  end

  # Removes ANSI escape sequences from a string.
  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*m/, text, "")
  end

  # Returns a highlighted version of `suggestion` relative to `input`.
  # Matching characters are in green; differing ones in red; extra characters (if any) in magenta.
  defp highlight_differences(input, suggestion) do
    input_chars = String.graphemes(input)
    sugg_chars = String.graphemes(suggestion)
    common = Enum.zip(input_chars, sugg_chars)

    highlighted =
      common
      |> Enum.map(fn {c1, c2} ->
        if c1 == c2 do
          "#{@ansi_green}#{c2}#{@ansi_reset}"
        else
          "#{@ansi_red}#{c2}#{@ansi_reset}"
        end
      end)
      |> Enum.join("")

    extra =
      if length(sugg_chars) > length(input_chars) do
        sugg_chars
        |> Enum.drop(length(input_chars))
        |> Enum.map(&"#{@ansi_magenta}#{&1}#{@ansi_reset}")
        |> Enum.join("")
      else
        ""
      end

    highlighted <> extra
  end

  # Computes a similarity score between two strings based on the Levenshtein distance.
  # The score is 1.0 for an exact match and decreases as the distance increases.
  defp similarity(a, b) do
    a = String.downcase(a)
    b = String.downcase(b)
    dist = levenshtein(a, b)
    max_len = max(String.length(a), String.length(b))
    if max_len == 0 do
      1.0
    else
      1.0 - dist / max_len
    end
  end

  # Computes the Levenshtein distance between two strings using dynamic programming.
  defp levenshtein(a, b) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)
    _la = length(a_chars)
    lb = length(b_chars)

    # Initialize the first row.
    initial = Enum.to_list(0..lb)

    Enum.reduce(a_chars, initial, fn ca, prev_row ->
      current_row = [List.first(prev_row) + 1]

      current_row =
        Enum.with_index(b_chars)
        |> Enum.reduce(current_row, fn {cb, j}, row ->
          cost = if ca == cb, do: 0, else: 1
          insertion = List.last(row) + 1
          deletion = Enum.at(prev_row, j + 1) + 1
          substitution = Enum.at(prev_row, j) + cost
          cell = min(insertion, min(deletion, substitution))
          row ++ [cell]
        end)

      current_row
    end)
    |> List.last()
  end
end
