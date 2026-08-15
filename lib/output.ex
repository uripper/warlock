defmodule Output do
  @moduledoc """
  A module for formatting and printing suggestion tables.

  This module provides functions to display a formatted table of close matches for a
  given command. It highlights differences between the input command and each suggestion,
  and optionally displays a similarity score if verbose mode is enabled.

  ## Features

    * Pads and aligns columns for suggested command, location, and similarity score.
    * Strips ANSI color codes from strings when calculating padding.
    * Highlights matching and differing characters using ANSI colors.

  ## Usage

      iex> Output.print_suggestions_table([{"cmd", 0.85}], "input", true)
  """

  @ansi_green IO.ANSI.green()
  @ansi_red IO.ANSI.red()
  @ansi_magenta IO.ANSI.magenta()
  @ansi_reset IO.ANSI.reset()

  @doc """
  Prints a formatted suggestions table.

  Given suggestion tuples along with the input command and verbose flag, this function
  prints a table with columns for the suggested command, its location, and optionally
  its similarity score formatted to two decimal places. Search results may carry their
  already-resolved path as `{suggestion, path, similarity}`.

  ## Parameters

    - `matches`: `{suggestion, similarity}` or `{suggestion, path, similarity}` tuples.
    - `command`: The original command (used for highlighting differences).
    - `verbose`: A boolean flag; if `true`, a similarity score column is displayed.

  ## Examples

      iex> Output.print_suggestions_table([{"ls", 0.95}], "ll", true)
  """
  @spec print_suggestions_table(
          [{String.t(), number()} | {String.t(), String.t(), number()}],
          String.t(),
          boolean()
        ) :: :ok
  def print_suggestions_table(matches, command, verbose) do
    case Enum.flat_map(matches, &resolve_match/1) do
      [] -> IO.puts("Command not found and no close matches.")
      resolved_matches -> print_table(resolved_matches, command, verbose)
    end
  end

  defp print_table(matches, command, verbose) do
    cmd_width = 20
    path_width = 50

    print_header(cmd_width, path_width, verbose)

    Enum.each(matches, fn match ->
      print_match(match, command, cmd_width, path_width, verbose)
    end)
  end

  defp print_header(cmd_width, path_width, verbose) do
    header =
      pad_string("Suggested Command", cmd_width) <>
        " | " <>
        pad_string("Location", path_width) <>
        if verbose, do: " | " <> pad_string("Similarity", 10), else: ""

    IO.puts(header)

    separator_length = cmd_width + path_width + 3 + if verbose, do: 13, else: 0

    "-"
    |> String.duplicate(separator_length)
    |> IO.puts()
  end

  defp print_match({suggestion, path, similarity}, command, cmd_width, path_width, verbose) do
    highlighted = highlight_differences(command, suggestion)

    line =
      pad_string(highlighted, cmd_width) <>
        " | " <>
        pad_string(path, path_width) <>
        format_similarity(similarity, verbose)

    IO.puts(line)
  end

  defp resolve_match({suggestion, similarity}) do
    case System.find_executable(suggestion) do
      nil -> []
      path -> [{suggestion, path, similarity}]
    end
  end

  defp resolve_match({suggestion, path, similarity}) do
    [{suggestion, path, similarity}]
  end

  # ===========================================
  # Formats the similarity score for display.
  # ===========================================
  defp format_similarity(similarity, verbose) do
    if verbose do
      formatted_similarity = :io_lib.format("~.2f", [similarity])
      similarity_str = IO.iodata_to_binary(formatted_similarity)
      " | " <> pad_string(similarity_str, 10)
    else
      ""
    end
  end

  # =============================================================
  # Pads a string with spaces until it reaches the given width.
  # =============================================================
  defp pad_string(text, width) do
    visible = strip_ansi(text)
    pad = max(width - String.length(visible), 0)
    text <> String.duplicate(" ", pad)
  end

  # =========================================
  # Strips ANSI escape codes from a string.
  # =========================================
  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*m/, text, "")
  end

  # ================================================================================
  # Highlights differences between the input command and a suggestion.
  #
  # Matching characters are colored green, mismatches red, and extra characters in
  # the suggestion (if any) are colored magenta.
  # ================================================================================
  defp highlight_differences(input, suggestion) do
    input_chars = String.graphemes(input)
    sugg_chars = String.graphemes(suggestion)
    common = Enum.zip(input_chars, sugg_chars)

    highlighted =
      Enum.map_join(common, fn {c1, c2} ->
        if c1 == c2 do
          "#{@ansi_green}#{c2}#{@ansi_reset}"
        else
          "#{@ansi_red}#{c2}#{@ansi_reset}"
        end
      end)

    extra =
      if length(sugg_chars) > length(input_chars) do
        sugg_chars
        |> Enum.drop(length(input_chars))
        |> Enum.map_join(&"#{@ansi_magenta}#{&1}#{@ansi_reset}")
      else
        ""
      end

    highlighted <> extra
  end
end
