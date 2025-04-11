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

  Given a list of suggestion tuples `{suggestion, similarity}` along with the input
  command and verbose flag, this function prints a table with columns for the suggested
  command, its location (as determined by `System.find_executable/1`), and optionally
  its similarity score formatted to two decimal places.

  ## Parameters

    - `matches`: A list of tuples in the form `{suggestion, similarity}`.
    - `command`: The original command (used for highlighting differences).
    - `verbose`: A boolean flag; if `true`, a similarity score column is displayed.

  ## Examples

      iex> Output.print_suggestions_table([{"ls", 0.95}], "ll", true)
  """
  def print_suggestions_table(matches, command, verbose) do
    cmd_width = 20
    path_width = 50

    valid_matches =
      matches
      |> Enum.filter(fn {suggestion, _sim} -> System.find_executable(suggestion) != nil end)

    if valid_matches == [] do
      IO.puts("Command not found and no close matches.")
    else
      # Build Table Header
      header =
        pad_string("Suggested Command", cmd_width) <>
          " | " <> pad_string("Location", path_width) <>
          (if verbose, do: " | " <> pad_string("Similarity", 10), else: "")

      IO.puts(header)

      sep_length = cmd_width + path_width + 3 + (if verbose, do: 13, else: 0)
      IO.puts(String.duplicate("-", sep_length))

      # Iterate and Print Matches
      Enum.each(valid_matches, fn {suggestion, sim} ->
        highlighted = highlight_differences(command, suggestion)
        suggestion_path = System.find_executable(suggestion)

        base_line =
          pad_string(highlighted, cmd_width) <>
            " | " <> pad_string(suggestion_path, path_width)

        line =
          base_line <>
            format_similarity(sim, verbose)

        IO.puts(line)
      end)
    end
  end


  #===========================================
  # Formats the similarity score for display.
  #===========================================
  defp format_similarity(similarity, verbose) do
    if verbose do
      similarity_str = :io_lib.format("~.2f", [similarity]) |> IO.iodata_to_binary()
      " | " <> pad_string(similarity_str, 10)
    else
      ""
    end
  end

  #=============================================================
  # Pads a string with spaces until it reaches the given width.
  #=============================================================
  defp pad_string(text, width) do
    visible = strip_ansi(text)
    pad = max(width - String.length(visible), 0)
    text <> String.duplicate(" ", pad)
  end

  #=========================================
  # Strips ANSI escape codes from a string.
  #=========================================
  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*m/, text, "")
  end

  #================================================================================
  # Highlights differences between the input command and a suggestion.
  #
  # Matching characters are colored green, mismatches red, and extra characters in
  # the suggestion (if any) are colored magenta.
  #================================================================================
  defp highlight_differences(input, suggestion) do
    input_chars = String.graphemes(input)
    sugg_chars = String.graphemes(suggestion)
    common = Enum.zip(input_chars, sugg_chars)

    highlighted =
      common
      |> Enum.map_join(fn {c1, c2} ->
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
