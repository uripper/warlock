defmodule Output do
  @ansi_green IO.ANSI.green()
  @ansi_red IO.ANSI.red()
  @ansi_magenta IO.ANSI.magenta()
  @ansi_reset IO.ANSI.reset()

  # Prints a formatted table of suggestions.
  def print_suggestions_table(matches, command, verbose) do
    cmd_width = 20
    path_width = 50

    valid_matches =
      matches
      |> Enum.filter(fn {suggestion, _sim} -> System.find_executable(suggestion) != nil end)

    if valid_matches == [] do
      IO.puts("Command not found and no close matches.")
    else
      # Build header; include Similarity column if verbose is true.
      header =
        pad_string("Suggested Command", cmd_width) <>
          " | " <> pad_string("Location", path_width) <>
          (if verbose, do: " | " <> pad_string("Similarity", 10), else: "")

      IO.puts(header)

      # Calculate header separator length.
      sep_length = cmd_width + path_width + 3 + (if verbose, do: 13, else: 0)
      IO.puts(String.duplicate("-", sep_length))

      Enum.each(valid_matches, fn {suggestion, sim} ->
        highlighted = highlight_differences(command, suggestion)
        suggestion_path = System.find_executable(suggestion)

        base_line =
          pad_string(highlighted, cmd_width) <>
            " | " <> pad_string(suggestion_path, path_width)

        # Append similarity score if verbose is true.
        line =
          if verbose do
            similarity_str = :io_lib.format("~.2f", [sim]) |> IO.iodata_to_binary()
            base_line <> " | " <> pad_string(similarity_str, 10)
          else
            base_line
          end

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
