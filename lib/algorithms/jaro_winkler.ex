defmodule JaroWinkler do
  @moduledoc """
  Computes the Jaro‑Winkler similarity between two strings.

  This module provides the algorithm to compute a similarity score between
  0.0 (no similarity) and 1.0 (exact match) using the Jaro‑Winkler method.
  The comparison is case‑insensitive.

  ## Examples

      iex> JaroWinkler.similarity("hello", "hallo")
      0.8666666666666667
  """

  # 1. Public API

  @doc """
  Computes the Jaro‑Winkler similarity score between two strings.

  ## Parameters
    - `s1` (String): the first string.
    - `s2` (String): the second string.

  ## Returns
    - Float in the range `0.0..1.0`.

  ## Examples

      iex> JaroWinkler.similarity("hello", "hallo")
      0.8666666666666667
  """
  def similarity(s1, s2) do
    s1 = String.downcase(s1)
    s2 = String.downcase(s2)
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)
    len1 = length(s1_chars)
    len2 = length(s2_chars)

    cond do
      len1 == 0 and len2 == 0 ->
        1.0

      len1 == 0 or len2 == 0 ->
        0.0

      true ->
        compute_jaro_winkler(s1_chars, s2_chars, len1, len2)
    end
  end

  # ============================
  # Jaro‑Winkler Helpers
  # ============================
  # Build lists of matched characters and count transpositions.
  defp list_constructor(s1_matches, s2_matches, s1_chars, s2_chars) do
    s1_matched =
      s1_matches
      |> Enum.with_index()
      |> Enum.filter(fn {flag, _} -> flag end)
      |> Enum.map(fn {_, idx} -> Enum.at(s1_chars, idx) end)

    s2_matched =
      s2_matches
      |> Enum.with_index()
      |> Enum.filter(fn {flag, _} -> flag end)
      |> Enum.map(fn {_, idx} -> Enum.at(s2_chars, idx) end)

    s1_matched
    |> Enum.zip(s2_matched)
    |> Enum.count(fn {c1, c2} -> c1 != c2 end)
    |> Kernel./(2)
  end

  # Extracts a match from the given range and updates s2_matches accordingly.
  defp extract_match(i, range, s1_chars, s2_chars, s2_matches) do
    Enum.reduce_while(range, {false, s2_matches}, fn j, {found, acc} ->
      if not found and not Enum.at(acc, j) and Enum.at(s1_chars, i) == Enum.at(s2_chars, j) do
        {:halt, {true, List.replace_at(acc, j, true)}}
      else
        {:cont, {found, acc}}
      end
    end)
  end

  # Scans the window [low, high] in s2 for a character that matches s1[i].
  # Returns {found?, updated_s2_matches}.
  defp find_match_in_window(i, low, high, s1_chars, s2_chars, s2_matches) do
    if low > high do
      {false, s2_matches}
    else
      extract_match(i, low..high, s1_chars, s2_chars, s2_matches)
    end
  end

  # ============================
  # Match‑Count Helpers
  # ============================
  defp count_matches_parallel(s1_chars, s2_chars, match_distance, len1, len2) do
    s1_matches = List.duplicate(false, len1)
    s2_matches0 = List.duplicate(false, len2)

    0..(len1 - 1)
    |> Task.async_stream(
      fn i ->
        low = max(0, i - match_distance)
        high = min(len2 - 1, i + match_distance)

        {found, s2_updated} =
          find_match_in_window(i, low, high, s1_chars, s2_chars, s2_matches0)

        {i, found, s2_updated}
      end,
      ordered: true,
      max_concurrency: System.schedulers_online()
    )
    |> Enum.reduce({0, s1_matches, s2_matches0}, fn {:ok, {i, found, s2_for_i}},
                                                   {count, s1_m, merged_s2_m} ->
      new_count = if found, do: count + 1, else: count
      new_s1_m = List.replace_at(s1_m, i, found)

      new_merged_s2_m =
        Enum.zip(merged_s2_m, s2_for_i)
        |> Enum.map(fn {a, b} -> a or b end)

      {new_count, new_s1_m, new_merged_s2_m}
    end)
  end

  defp count_matches_sequential(s1_chars, s2_chars, match_distance, len1, len2) do
    s1_matches = List.duplicate(false, len1)
    s2_matches0 = List.duplicate(false, len2)

    Enum.reduce(0..(len1 - 1), {0, s1_matches, s2_matches0}, fn i, {m, s1_m, s2_m} ->
      low = max(0, i - match_distance)
      high = min(len2 - 1, i + match_distance)

      {found, updated_s2_m} =
        find_match_in_window(i, low, high, s1_chars, s2_chars, s2_m)

      new_m = if found, do: m + 1, else: m
      {new_m, List.replace_at(s1_m, i, found), updated_s2_m}
    end)
  end

  # Counts matches between the two strings under the Jaro window rule.
  # Returns {match_count, s1_match_flags, s2_match_flags}.
  defp count_matches(s1_chars, s2_chars, match_distance) do
    len1 = length(s1_chars)
    len2 = length(s2_chars)

    if len1 > 20 and len2 > 20 do
      count_matches_parallel(s1_chars, s2_chars, match_distance, len1, len2)
    else
      count_matches_sequential(s1_chars, s2_chars, match_distance, len1, len2)
    end
  end

  # ============================
  # Prefix & Score Computation
  # ============================
  # Finds the common prefix length.
  defp find_prefix_length(s1_chars, s2_chars) do
    Enum.zip(s1_chars, s2_chars)
    |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
    |> Enum.count()
  end

  # Computes the full Jaro‑Winkler score.
  defp compute_jaro_winkler(s1_chars, s2_chars, len1, len2) do
    match_distance = max(div(max(len1, len2), 2) - 1, 0)

    {matches, s1_matches, s2_matches} =
      count_matches(s1_chars, s2_chars, match_distance)

    if matches == 0 do
      0.0
    else
      transpositions = list_constructor(s1_matches, s2_matches, s1_chars, s2_chars)

      jaro =
        (matches / len1 + matches / len2 +
         (matches - transpositions) / matches) / 3.0

      prefix_length = find_prefix_length(s1_chars, s2_chars)

      jaro + prefix_length * 0.1 * (1 - jaro)
    end
  end
end
