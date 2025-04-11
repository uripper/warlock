defmodule Levenshtein do
  @moduledoc """
  Computes the Levenshtein similarity between two strings.

  This module calculates the edit distance between two strings using the
  Levenshtein algorithm. The raw distance is normalized based on the maximum
  length of the two inputs so that the resulting similarity score is a float
  between 0.0 (no similarity) and 1.0 (exact match).

  The sensitivity parameter controls the penalty for mismatches.

  ## Examples

      iex> Levenshtein.similarity("kitten", "sitting", 1)
      0.5714285714285714
  """

  # 1. Public API

  @doc """
  Computes the normalized Levenshtein similarity score between two strings.

  ## Parameters
    - `a` (String): the first string.
    - `b` (String): the second string.
    - `sensitivity` (number): the mismatch penalty (used to adjust the cost
      when characters differ).

  ## Returns
    - Float in the range `0.0..1.0`.

  ## Examples

      iex> Levenshtein.similarity("kitten", "sitting", 1)
      0.5714285714285714
  """
  def similarity(a, b, sensitivity) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)
    la = length(a_chars)
    lb = length(b_chars)

    # Seed matrix with row / column indices.
    base_matrix =
      for i <- 0..la do
        for j <- 0..lb do
          cond do
            i == 0 -> j
            j == 0 -> i
            true -> 0
          end
        end
      end

    updated_matrix =
      if la > 10 and lb > 10 do
        parallel_update(base_matrix, a_chars, b_chars, sensitivity, la, lb)
      else
        sequential_update(base_matrix, a_chars, b_chars, sensitivity, la, lb)
      end

    Enum.at(Enum.at(updated_matrix, la), lb)
  end


  # ====================
  # Levenshtein helpers
  # ====================

  # Computes the edit‑distance value for a single matrix cell (i, j).
  defp compute_distance_cell(a_chars, b_chars, i, j, matrix, sensitivity) do
    cost = if Enum.at(a_chars, i - 1) == Enum.at(b_chars, j - 1), do: 0, else: sensitivity

    deletion = Enum.at(Enum.at(matrix, i - 1), j) + 1
    insertion = Enum.at(Enum.at(matrix, i), j - 1) + 1
    substitution = Enum.at(Enum.at(matrix, i - 1), j - 1) + cost

    min(deletion, min(insertion, substitution))
  end

  # Update a value inside the 2‑D matrix.
  defp update_matrix(matrix, i, j, value) do
    List.update_at(matrix, i, fn row -> List.replace_at(row, j, value) end)
  end

  # Build a full matrix row sequentially (used by sequential update).
  defp update_row_sequential(i, matrix, a_chars, b_chars, sensitivity, lb) do
    Enum.reduce(1..lb, matrix, fn j, acc ->
      cell = compute_distance_cell(a_chars, b_chars, i, j, acc, sensitivity)
      update_matrix(acc, i, j, cell)
    end)
  end

  # Sequential update of the matrix (used when inputs are small).
  defp sequential_update(matrix, a_chars, b_chars, sensitivity, la, lb) do
    Enum.reduce(1..la, matrix, fn i, acc ->
      update_row_sequential(i, acc, a_chars, b_chars, sensitivity, lb)
    end)
  end

  # Parallel update of the matrix (used when inputs are large).
  defp parallel_update(matrix, a_chars, b_chars, sensitivity, la, lb) do
    1..la
    |> Task.async_stream(
      fn i ->
        row = Enum.at(matrix, i)

        updated_row =
          Enum.reduce(1..lb, row, fn j, row_acc ->
            cell =
              compute_distance_cell(
                a_chars,
                b_chars,
                i,
                j,
                List.replace_at(matrix, i, row_acc),
                sensitivity
              )

            List.replace_at(row_acc, j, cell)
          end)

        {i, updated_row}
      end,
      ordered: true,
      max_concurrency: System.schedulers_online()
    )
    |> Enum.reduce(matrix, fn {:ok, {i, row}}, acc ->
      List.replace_at(acc, i, row)
    end)
  end
end
