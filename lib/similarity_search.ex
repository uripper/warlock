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

  @type algorithm :: :jaro_winkler | :levenshtein

  @type prepared_query ::
          %{
            algorithm: :jaro_winkler,
            normalized: String.t(),
            prefix: [String.grapheme()]
          }
          | %{
              algorithm: :levenshtein,
              graphemes: [String.grapheme()],
              length: non_neg_integer(),
              normalized: String.t()
            }

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
    * `verbose` – Flag to enable verbose output (currently ignored).
    * `algorithm` – `:levenshtein` or `:jaro_winkler`.

  ## Returns

    * Float in the range `0.0..1.0`.

  ## Examples

      iex> Similaritysearch.similarity("foo", "f00", 1.0, false, :levenshtein)
      0.66
  """
  @spec similarity(String.t(), String.t(), number(), boolean(), algorithm()) :: float()
  def similarity(a, b, sensitivity, _, algorithm) do
    a
    |> prepare_query(algorithm)
    |> similarity_to_prepared_query(b, sensitivity)
  end

  @doc false
  @spec prepare_query(String.t(), algorithm()) :: prepared_query()
  def prepare_query(query, algorithm) do
    query
    |> String.downcase()
    |> prepare_normalized_query(algorithm)
  end

  @doc false
  @spec similarity_to_normalized_query(String.t(), String.t(), number(), algorithm()) :: float()
  def similarity_to_normalized_query(normalized_query, candidate, sensitivity, algorithm) do
    normalized_query
    |> prepare_normalized_query(algorithm)
    |> similarity_to_prepared_query(candidate, sensitivity)
  end

  @doc false
  @spec score_candidate(prepared_query(), String.t(), number(), float()) ::
          {:ok, float()} | :below_threshold
  def score_candidate(prepared_query, candidate, sensitivity, threshold) do
    normalized_candidate = String.downcase(candidate)

    case prepared_query do
      %{algorithm: :jaro_winkler} ->
        prepared_query
        |> jaro_winkler_similarity(normalized_candidate)
        |> qualifying_score(threshold)

      %{algorithm: :levenshtein} ->
        levenshtein_score(prepared_query, normalized_candidate, sensitivity, threshold)
    end
  end

  defp prepare_normalized_query(normalized_query, :jaro_winkler) do
    %{
      algorithm: :jaro_winkler,
      normalized: normalized_query,
      prefix: JaroWinkler.prepare_prefix(normalized_query)
    }
  end

  defp prepare_normalized_query(normalized_query, :levenshtein) do
    graphemes = String.graphemes(normalized_query)

    %{
      algorithm: :levenshtein,
      normalized: normalized_query,
      graphemes: graphemes,
      length: length(graphemes)
    }
  end

  defp similarity_to_prepared_query(prepared_query, candidate, sensitivity) do
    normalized_candidate = String.downcase(candidate)

    case prepared_query do
      %{algorithm: :jaro_winkler} ->
        jaro_winkler_similarity(prepared_query, normalized_candidate)

      %{algorithm: :levenshtein} ->
        candidate_graphemes = String.graphemes(normalized_candidate)
        candidate_length = length(candidate_graphemes)
        max_length = max(prepared_query.length, candidate_length)

        if max_length == 0 do
          1.0
        else
          1.0 -
            Levenshtein.similarity_graphemes(
              {prepared_query.graphemes, prepared_query.length},
              {candidate_graphemes, candidate_length},
              sensitivity,
              :infinity
            ) / max_length
        end
    end
  end

  defp jaro_winkler_similarity(prepared_query, normalized_candidate) do
    JaroWinkler.similarity_prepared(
      prepared_query.normalized,
      prepared_query.prefix,
      normalized_candidate
    )
  end

  defp levenshtein_score(prepared_query, normalized_candidate, sensitivity, threshold) do
    candidate_graphemes = String.graphemes(normalized_candidate)
    candidate_length = length(candidate_graphemes)
    max_length = max(prepared_query.length, candidate_length)

    cond do
      max_length == 0 ->
        {:ok, 1.0}

      length_bound_below_threshold?(
        prepared_query.length,
        candidate_length,
        max_length,
        sensitivity,
        threshold
      ) ->
        :below_threshold

      true ->
        max_distance = (1.0 - threshold) * max_length

        case Levenshtein.similarity_graphemes(
               {prepared_query.graphemes, prepared_query.length},
               {candidate_graphemes, candidate_length},
               sensitivity,
               distance_limit(sensitivity, max_distance)
             ) do
          :above_limit ->
            :below_threshold

          distance ->
            qualifying_score(1.0 - distance / max_length, threshold)
        end
    end
  end

  defp length_bound_below_threshold?(
         query_length,
         candidate_length,
         max_length,
         sensitivity,
         threshold
       ) do
    sensitivity >= 0 and
      abs(query_length - candidate_length) > (1.0 - threshold) * max_length
  end

  defp distance_limit(sensitivity, max_distance) when sensitivity >= 0, do: max_distance
  defp distance_limit(_, _), do: :infinity

  defp qualifying_score(score, threshold) when score >= threshold, do: {:ok, score}
  defp qualifying_score(_, _), do: :below_threshold
end
