defmodule JaroWinkler do
  @moduledoc """
  Computes the Jaro‑Winkler similarity between two strings.

  The result is a float between 0.0 (no similarity) and 1.0 (exact match).
  All comparisons are case‑insensitive.

  ## Examples

      iex> JaroWinkler.similarity("hello", "hallo")
      0.8666666666666667
  """

  # 1. Public API
  # --------------
  @doc """
  Jaro‑Winkler similarity between `s1` and `s2`.

  ## Parameters
    * `s1` – first string.
    * `s2` – second string.

  ## Returns
    * Float in the range `0.0..1.0`.
  """
  def similarity(s1, s2) do
    s1_chars = s1 |> String.downcase() |> String.graphemes()
    s2_chars = s2 |> String.downcase() |> String.graphemes()
    len1 = length(s1_chars)
    len2 = length(s2_chars)

    cond do
      len1 == 0 and len2 == 0 -> 1.0
      len1 == 0 or len2 == 0 -> 0.0
      true -> compute_jaro_winkler(s1_chars, s2_chars, len1, len2)
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

  # Extracts a match from the given range and updates `s2_matches`.
  # Uses Enum.at/3 with a default to ensure a boolean is returned.
  defp extract_match(i, range, s1_chars, s2_chars, s2_matches) do
    Enum.reduce_while(range, {false, s2_matches}, fn j, {found, acc} ->
      if not found and
           not Enum.at(acc, j, true) and
           Enum.at(s1_chars, i) == Enum.at(s2_chars, j) do
        {:halt, {true, List.replace_at(acc, j, true)}}
      else
        {:cont, {found, acc}}
      end
    end)
  end

  # Scan the window [low, high] in s2 for a character that matches s1[i].
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
  defp count_matches_sequential(s1_chars, s2_chars, match_distance, len1, len2) do
    s1_matches = List.duplicate(false, len1)
    s2_matches = List.duplicate(false, len2)

    Enum.reduce(0..(len1 - 1), {0, s1_matches, s2_matches}, fn i, {m, s1_m, s2_m} ->
      low  = max(0, i - match_distance)
      high = min(len2 - 1, i + match_distance)

      {found, updated_s2_m} =
        find_match_in_window(i, low, high, s1_chars, s2_chars, s2_m)

      new_m = if found, do: m + 1, else: m
      {new_m, List.replace_at(s1_m, i, found), updated_s2_m}
    end)
  end

  # Counts matches under the Jaro window rule.
  defp count_matches(s1_chars, s2_chars, match_distance) do
    len1 = length(s1_chars)
    len2 = length(s2_chars)
    count_matches_sequential(s1_chars, s2_chars, match_distance, len1, len2)
  end

  # ============================
  # Prefix & Score Computation
  # ============================
  # Find common prefix length (capped at 4 characters per classical spec).
  defp find_prefix_length(s1_chars, s2_chars) do
    Enum.zip(s1_chars, s2_chars)
    |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
    |> Enum.take(4)
    |> Enum.count()
  end

  # Compute the full Jaro-Winkler score.
  defp compute_jaro_winkler(s1_chars, s2_chars, len1, len2) do
    match_distance = max(div(max(len1, len2), 2) - 1, 0)
    {matches, s1_matches, s2_matches} = count_matches(s1_chars, s2_chars, match_distance)

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
