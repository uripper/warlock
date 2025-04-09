
defmodule Output do
  @ansi_green IO.ANSI.green()
  @ansi_red IO.ANSI.red()
  @ansi_magenta IO.ANSI.magenta()
  @ansi_reset IO.ANSI.reset()

  # Prints a formatted table of suggestions.
  def print_suggestions_table(matches, command, _verbose) do
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
end
