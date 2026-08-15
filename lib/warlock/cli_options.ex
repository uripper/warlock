defmodule Warlock.CliOptions do
  @moduledoc """
  Normalizes parsed command-line options into search options.
  """

  require Logger

  @default_sensitivity 1.0
  @default_threshold 0.75
  @default_matches 5

  @type t :: %{
          algorithm: :jaro_winkler | :levenshtein,
          ignore_patterns: [String.t()],
          ignored_directories: [String.t()],
          num_matches: pos_integer(),
          sensitivity: float(),
          threshold: float(),
          verbose: boolean()
        }

  @type defaults :: %{
          matches: pos_integer(),
          sensitivity: float(),
          threshold: float()
        }

  @spec defaults() :: defaults()
  def defaults do
    %{
      matches: @default_matches,
      sensitivity: @default_sensitivity,
      threshold: @default_threshold
    }
  end

  @spec from_keyword(keyword()) :: t()
  def from_keyword(options) do
    %{
      algorithm: algorithm(options),
      ignore_patterns: ignore_patterns(options),
      ignored_directories: ignored_directories(options),
      num_matches: num_matches(options),
      sensitivity: sensitivity(options),
      threshold: threshold(options),
      verbose: verbose(options)
    }
  end

  defp verbose(options), do: Keyword.get(options, :verbose, false)

  defp sensitivity(options) do
    options
    |> Keyword.get(:sensitivity)
    |> parse_sensitivity()
  end

  defp algorithm(options) do
    options
    |> Keyword.get(:algorithm)
    |> parse_algorithm()
  end

  defp threshold(options) do
    options
    |> Keyword.get(:threshold)
    |> parse_threshold()
  end

  defp num_matches(options) do
    options
    |> Keyword.get(:matches)
    |> parse_matches()
  end

  defp ignore_patterns(options) do
    options
    |> Keyword.get(:ignore, "")
    |> parse_list_option()
  end

  defp ignored_directories(options) do
    options
    |> Keyword.get(:ignoredir, "")
    |> parse_list_option()
  end

  defp parse_sensitivity(nil), do: @default_sensitivity

  defp parse_sensitivity(value) when is_binary(value) do
    value
    |> ensure_leading_zero()
    |> Float.parse()
    |> sensitivity_value()
  end

  defp parse_sensitivity(value), do: value

  defp sensitivity_value({value, _}), do: value
  defp sensitivity_value(:error), do: @default_sensitivity

  defp parse_algorithm("levenshtein"), do: :levenshtein
  defp parse_algorithm("lev"), do: :levenshtein
  defp parse_algorithm("jaro_winkler"), do: :jaro_winkler
  defp parse_algorithm("jw"), do: :jaro_winkler
  defp parse_algorithm(_), do: :jaro_winkler

  defp parse_threshold(nil), do: @default_threshold

  defp parse_threshold(value) when is_binary(value) do
    normalized_value = ensure_leading_zero(value)

    case Float.parse(normalized_value) do
      {threshold, ""} when threshold >= 0.0 and threshold <= 1.0 ->
        threshold

      _ ->
        Logger.warning(
          "Invalid threshold value: #{normalized_value}. Using default #{@default_threshold}"
        )

        @default_threshold
    end
  end

  defp parse_threshold(_), do: @default_threshold

  defp parse_matches(nil), do: @default_matches

  defp parse_matches(value) when is_binary(value) do
    case Integer.parse(value) do
      {matches, ""} when matches >= 1 ->
        matches

      _ ->
        IO.puts(:stderr, "--matches must be an integer ≥ 1")
        System.halt(1)
    end
  end

  defp parse_list_option(""), do: []

  defp parse_list_option(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp ensure_leading_zero("." <> _ = value), do: "0" <> value
  defp ensure_leading_zero(value), do: value
end
