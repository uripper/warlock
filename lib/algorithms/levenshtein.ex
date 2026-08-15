defmodule Levenshtein do
  @moduledoc """
  Computes the Levenshtein edit distance between two strings.

  The raw distance can be normalized by the caller to produce a similarity
  score. The sensitivity parameter controls the substitution cost.

  ## Examples

      iex> Levenshtein.similarity("kitten", "sitting", 1)
      3
  """

  # 1. Public API
  # --------------
  @doc """
  Computes the Levenshtein edit distance between two strings.

  ## Parameters
    - `a` (String): the first string.
    - `b` (String): the second string.
    - `sensitivity` (number): the mismatch penalty (used to adjust the cost
      when characters differ).

  ## Returns
    - The numeric edit distance between the strings.

  ## Examples

      iex> Levenshtein.similarity("kitten", "sitting", 1)
      3
  """
  @spec similarity(String.t(), String.t(), number()) :: number()
  def similarity(a, b, sensitivity) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)

    similarity_graphemes(
      {a_chars, length(a_chars)},
      {b_chars, length(b_chars)},
      sensitivity,
      :infinity
    )
  end

  @doc false
  @spec similarity_graphemes(
          {[String.grapheme()], non_neg_integer()},
          {[String.grapheme()], non_neg_integer()},
          number(),
          number() | :infinity
        ) :: number() | :above_limit
  def similarity_graphemes(first, second, sensitivity, max_distance) do
    {{row_characters, row_length}, {column_characters, _}} = shortest_row(first, second)
    initial_row = Enum.to_list(0..row_length)

    column_characters
    |> Enum.with_index(1)
    |> Enum.reduce_while(initial_row, fn {character, row_index}, previous_row ->
      {row, row_minimum} =
        update_row(character, row_index, previous_row, row_characters, sensitivity)

      if above_limit?(row_minimum, max_distance) do
        {:halt, :above_limit}
      else
        {:cont, row}
      end
    end)
    |> final_distance()
  end

  # ====================
  # Levenshtein Helpers
  # ====================

  # Builds one distance row from the preceding row. Rows are accumulated in
  # reverse so adding a cell remains constant-time.
  defp update_row(column_character, row_index, previous_row, row_characters, sensitivity) do
    [upper_left | above_cells] = previous_row

    build_row(
      row_characters,
      above_cells,
      column_character,
      sensitivity,
      {upper_left, row_index, row_index, [row_index]}
    )
  end

  defp build_row([], [], _, _, {_, _, row_minimum, reversed_row}) do
    {Enum.reverse(reversed_row), row_minimum}
  end

  defp build_row(
         [row_character | row_characters],
         [above | above_cells],
         column_character,
         sensitivity,
         {upper_left, left, row_minimum, reversed_row}
       ) do
    distance =
      compute_distance_cell(
        column_character,
        row_character,
        {upper_left, above, left},
        sensitivity
      )

    build_row(
      row_characters,
      above_cells,
      column_character,
      sensitivity,
      {above, distance, min(row_minimum, distance), [distance | reversed_row]}
    )
  end

  defp compute_distance_cell(a_character, b_character, distances, sensitivity) do
    {upper_left, above, left} = distances
    substitution_cost = mismatch_cost(a_character, b_character, sensitivity)

    min(above + 1, min(left + 1, upper_left + substitution_cost))
  end

  defp mismatch_cost(character, character, _), do: 0
  defp mismatch_cost(_, _, sensitivity), do: sensitivity

  defp shortest_row({_, first_length} = first, {_, second_length} = second)
       when first_length <= second_length,
       do: {first, second}

  defp shortest_row(first, second), do: {second, first}

  defp above_limit?(_, :infinity), do: false
  defp above_limit?(row_minimum, max_distance), do: row_minimum > max_distance

  defp final_distance(:above_limit), do: :above_limit
  defp final_distance(row), do: List.last(row)
end
