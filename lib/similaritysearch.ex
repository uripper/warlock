defmodule Similaritysearch do
  @moduledoc """
  A module for performing similarity searches.
  """

  @doc """
  Function to calculate similarity between two items.
  """
def similarity(a, b, sensitivity, verbose, algorithm) do
  if verbose, do: IO.puts("Comparing: #{a} and #{b}, Sensitivity: #{sensitivity}, Algorithm: #{algorithm}")
  a = String.downcase(a)
  b = String.downcase(b)

  similarity_score =
    case algorithm do
      :levenshtein ->
        max_len = max(String.length(a), String.length(b))
        if max_len == 0 do
          1.0
        else
          # Convert Levenshtein distance to similarity.
          1.0 - levenshtein(a, b, sensitivity) / max_len
        end

      :jaro_winkler ->
        # Jaro-Winkler already gives a similarity score.
        jaro_winkler(a, b)

      _ ->
        # Default to levenshtein if algorithm is unrecognized.
        max_len = max(String.length(a), String.length(b))
        if max_len == 0 do
          1.0
        else
          1.0 - levenshtein(a, b, sensitivity) / max_len
        end
    end

  similarity_score
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

  # Computes the Jaro-Winkler similarity score between two strings.
  # The score is between 0.0 (no similarity) and 1.0 (exact match).
  defp jaro_winkler(s1, s2) do
    # Preprocess: convert to lowercase and split into graphemes.
    s1 = String.downcase(s1)
    s2 = String.downcase(s2)
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)
    len1 = length(s1_chars)
    len2 = length(s2_chars)

    # Special cases if one or both strings are empty.
    cond do
      len1 == 0 and len2 == 0 ->
        1.0

      len1 == 0 or len2 == 0 ->
        0.0

      true ->
        match_distance = max(div(max(len1, len2), 2) - 1, 0)

        # Initialize boolean lists tracking which characters are matched.
        s1_matches = List.duplicate(false, len1)
        s2_matches = List.duplicate(false, len2)

        # Find matching characters.
        {matches, s1_matches, s2_matches} =
          Enum.reduce(0..(len1 - 1), {0, s1_matches, s2_matches}, fn i, {m, s1_m, s2_m} ->
            low = max(0, i - match_distance)
            high = min(len2 - 1, i + match_distance)

            {found, updated_s2_m} =
              if low > high do
                # If the range is empty, no matching character is possible for this index.
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
          # Build the list of matched characters.
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

          jaro =
            (matches / len1 + matches / len2 + (matches - transpositions) / matches) / 3.0

          prefix_length =
            s1_chars
            |> Enum.zip(s2_chars)
            |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
            |> Enum.count()
            |> min(4)

          jaro + prefix_length * 0.1 * (1 - jaro)
        end
    end
  end
end
