defmodule Similaritysearch do
  @moduledoc """
  A module for performing similarity searches between two strings.

  This module provides functions to calculate a similarity score based on two
  different algorithms: Levenshtein distance (converted to a similarity metric) and
  Jaro‑Winkler. The score is a floating‑point number between 0.0 (no similarity)
  and 1.0 (exact match).

  ## Algorithms

    * `:levenshtein` – Computes the Levenshtein distance, normalises it to produce
      a similarity score.
    * `:jaro_winkler` – Computes the Jaro‑Winkler similarity score directly.

  ## Usage

      iex> Similaritysearch.similarity("hello", "hallo", 1.0, false, :levenshtein)
      0.8
  """

  @doc """
  Calculates the similarity score between two strings.

  The score is computed based on the selected algorithm and the provided
  sensitivity. When using the Levenshtein algorithm, the computed distance is
  normalised by the maximum length of the two strings to produce a score between
  0.0 and 1.0.

  ## Parameters

    * `a` – First string.
    * `b` – Second string.
    * `sensitivity` – Penalty value for character mismatches (used in
      Levenshtein).
    * `_verbose` – Flag to enable verbose output (ignored here).
    * `algorithm` – `:levenshtein` or `:jaro_winkler`.

  ## Returns

    * Float in the range `0.0..1.0`.

  ## Examples

      iex> Similaritysearch.similarity("foo", "f00", 1.0, false, :levenshtein)
      0.66
  """
  def similarity(a, b, sensitivity, _verbose, algorithm) do
    a = String.downcase(a)
    b = String.downcase(b)

    case algorithm do
      :levenshtein ->
        max_len = max(String.length(a), String.length(b))

        if max_len == 0 do
          1.0
        else
          1.0 - Levenshtein.similarity(a, b, sensitivity) / max_len
        end

      :jaro_winkler ->
        JaroWinkler.similarity(a, b)
    end
  end
end
