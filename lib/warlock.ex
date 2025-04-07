defmodule Warlock do
  @moduledoc """
  A smarter 'which' command with fuzzy matching.

  Usage:
      warlock [--verbose] [--sensitivity=VALUE] <command>
  """

  @ansi_green IO.ANSI.green()
  @ansi_red IO.ANSI.red()
  @ansi_magenta IO.ANSI.magenta()
  @ansi_reset IO.ANSI.reset()

  # Public entry point called by the escript runtime.
  def main(args) do
    case parse_args(args) do
      {verbose, command, sensitivity} when not is_nil(command) ->
        witch(command, verbose, sensitivity)
      _ ->
        IO.puts("Usage: warlock [--verbose] [--sensitivity=VALUE] <command>")
    end
  end

  defp parse_args(args) do
    # Use OptionParser to handle both flags.
    {opts, remaining, _} =
      OptionParser.parse(args, switches: [verbose: :boolean, sensitivity: :string])

    verbose = Keyword.get(opts, :verbose, false)

    sensitivity =
      case Keyword.get(opts, :sensitivity) do
        nil ->
          1.0
        s when is_binary(s) ->
          s =
            if String.starts_with?(s, ".") do
              "0" <> s
            else
              s
            end

          case Float.parse(s) do
            {value, _} -> value
            :error -> 1.0
          end
        other ->
          other
      end

    command = List.first(remaining)
    {verbose, command, sensitivity}
  end

  # Attempts to locate an executable in the system PATH. If an exact match isn’t found,
  # performs fuzzy matching against all executables in the PATH.
  def witch(command, verbose, sensitivity) do
    if verbose, do: IO.puts("Searching for '#{command}' in PATH...")

    if (path = System.find_executable(command)) do
      if verbose, do: IO.puts("Exact match found: #{path}")
      IO.puts(path)
      path
    else
      if verbose, do: IO.puts("Exact match not found. Gathering all executables from PATH...")
      executables = get_all_executables(verbose)

      if verbose, do: IO.puts("Calculating similarities for fuzzy matching (sensitivity = #{sensitivity})...")
      matches =
        executables
        |> Enum.map(fn exe -> {exe, similarity(command, exe, sensitivity, verbose)} end)
        |> Enum.filter(fn {_exe, sim} -> sim >= 0.6 end)
        |> Enum.sort_by(fn {_exe, sim} -> -sim end)
        |> Enum.take(5)

      if matches == [] do
        IO.puts("Command not found and no close matches.")
      else
        IO.puts("\nCommand '#{command}' not found. Close matches:\n")
        print_suggestions_table(matches, command, verbose)
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

  # Prints a formatted table of suggestions.
  defp print_suggestions_table(matches, command, _verbose) do
    cmd_width = 20
    path_width = 50

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

  defp pad_string(text, width) do
    visible = strip_ansi(text)
    pad = max(width - String.length(visible), 0)
    text <> String.duplicate(" ", pad)
  end

  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*m/, text, "")
  end

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

  defp similarity(a, b, sensitivity, verbose) do
    if verbose, do: IO.puts("Comparing: #{a} and #{b}, Sensitivity: #{sensitivity}")
    a = String.downcase(a)
    b = String.downcase(b)
    dist = levenshtein(a, b, sensitivity)
    max_len = max(String.length(a), String.length(b))
    if max_len == 0 do
      1.0
    else
      1.0 - dist / max_len
    end
  end

  defp levenshtein(a, b, sensitivity) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)
    la = length(a_chars)
    lb = length(b_chars)

    matrix =
      for i <- 0..la do
        for j <- 0..lb do
          cond do
            i == 0 -> j
            j == 0 -> i
            true -> 0
          end
        end
      end

    matrix =
      Enum.reduce(1..la, matrix, fn i, m ->
        Enum.reduce(1..lb, m, fn j, m_inner ->
          cost =
            if Enum.at(a_chars, i - 1) == Enum.at(b_chars, j - 1),
              do: 0,
              else: sensitivity

          deletion = Enum.at(Enum.at(m_inner, i - 1), j) + 1
          insertion = Enum.at(Enum.at(m_inner, i), j - 1) + 1
          substitution = Enum.at(Enum.at(m_inner, i - 1), j - 1) + cost
          cell = min(deletion, min(insertion, substitution))
          update_matrix(m_inner, i, j, cell)
        end)
      end)

    Enum.at(Enum.at(matrix, la), lb)
  end

  defp update_matrix(matrix, i, j, value) do
    List.update_at(matrix, i, fn row ->
      List.replace_at(row, j, value)
    end)
  end
end
