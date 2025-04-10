defmodule Similaritysearch do
  @moduledoc """
  A module for performing similarity searches between two strings.

  This module provides functions to calculate a similarity score based on two
  different algorithms: Levenshtein distance (converted to a similarity metric) and
  Jaro-Winkler. The score is a floating-point number between 0.0 (no similarity)
  and 1.0 (exact match).

  ## Algorithms

    * `:levenshtein` – Computes the Levenshtein distance, normalizes it to produce a
       similarity score.
    * `:jaro_winkler` – Computes the Jaro-Winkler similarity score directly.

  ## Usage

      iex> Similaritysearch.similarity("hello", "hallo", 1.0, false, :levenshtein)
      0.8
  """

  @doc """
  Calculates the similarity score between two strings.

  The score is computed based on the selected algorithm and the provided sensitivity.
  When using the Levenshtein algorithm, the computed distance is normalized by the
  maximum length of the two strings to produce a score between 0.0 and 1.0.

  ## Parameters

    - `a`: First string.
    - `b`: Second string.
    - `sensitivity`: The penalty value for character mismatches (used in Levenshtein).
    - `_verbose`: A flag to enable verbose output (ignored here).
    - `algorithm`: The algorithm to use (`:levenshtein` or `:jaro_winkler`).

  ## Returns

    - A float between 0.0 (no similarity) and 1.0 (exact match).

  ## Examples

      iex> Similaritysearch.similarity("foo", "f00", 1.0, false, :levenshtein)
      0.66
  """
  def similarity(a, b, sensitivity, _verbose, algorithm) do
    a = String.downcase(a)
    b = String.downcase(b)

    similarity_score =
      case algorithm do
        :levenshtein ->
          max_len = max(String.length(a), String.length(b))

          if max_len == 0 do
            1.0
          else
            # Convert Levenshtein distance to similarity
            1.0 - levenshtein(a, b, sensitivity) / max_len
          end

        :jaro_winkler ->
          # Jaro-Winkler directly provides a similarity score.
          jaro_winkler(a, b)
      end

    similarity_score
  end

  # ==============================================================================
  # Private Functions: Levenshtein Algorithm
  # Computes the Levenshtein distance between two strings. The sensitivity value
  # adjusts the cost of a mismatch.
  # ==============================================================================
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

  @doc false
  # Helper function to update the cell in a 2D matrix.
  defp update_matrix(matrix, i, j, value) do
    List.update_at(matrix, i, fn row ->
      List.replace_at(row, j, value)
    end)
  end

  # ===============================================================
  # Private Functions: Jaro-Winkler Algorithm
  # Computes the Jaro-Winkler similarity score between two strings.
  # The score is between 0.0 (no similarity) and 1.0 (exact match).
  # ===============================================================
  defp jaro_winkler(s1, s2) do
    # Preprocess: convert strings to lowercase and split into graphemes.
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
        match_distance = max(div(max(len1, len2), 2) - 1, 0)

        # Track matched characters for both strings.
        s1_matches = List.duplicate(false, len1)
        s2_matches = List.duplicate(false, len2)

        {matches, s1_matches, s2_matches} =
          Enum.reduce(0..(len1 - 1), {0, s1_matches, s2_matches}, fn i, {m, s1_m, s2_m} ->
            low = max(0, i - match_distance)
            high = min(len2 - 1, i + match_distance)

            {found, updated_s2_m} =
              if low > high do
                {false, s2_m}
              else
                Enum.reduce_while(low..high, {false, s2_m}, fn j, {found, acc} ->
                  if not found and not Enum.at(acc, j) and
                       Enum.at(s1_chars, i) == Enum.at(s2_chars, j) do
                    {:halt, {true, List.replace_at(acc, j, true)}}
                  else
                    {:cont, {found, acc}}
                  end
                end)
              end

            new_m = if found, do: m + 1, else: m
            {new_m, List.replace_at(s1_m, i, found), updated_s2_m}
          end)

        if matches == 0 do
          0.0
        else
          # Construct the lists of matched characters.
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

          transpositions =
            s1_matched
            |> Enum.zip(s2_matched)
            |> Enum.count(fn {c1, c2} -> c1 != c2 end)
            |> Kernel./(2)

          # Calculate the basic Jaro score.
          jaro =
            (matches / len1 + matches / len2 + (matches - transpositions) / matches) / 3.0

          prefix_length =
            s1_chars
            |> Enum.zip(s2_chars)
            |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
            |> Enum.count()
            |> min(4)

          # Incorporate Winkler's bonus for common prefixes.
          jaro + prefix_length * 0.1 * (1 - jaro)
        end
    end
  end
end
