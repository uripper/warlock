defmodule JaroWinkler do
  @moduledoc """
  Computes case-insensitive Jaro-Winkler similarity between two strings.

  The result is a float between `0.0` for no similarity and `1.0` for an
  exact match.

  ## Examples

      iex> JaroWinkler.similarity("hello", "hallo")
      0.88
  """

  @max_prefix_length 4
  @scaling_factor 0.1
  @boost_threshold 0.7

  @doc """
  Computes the case-insensitive Jaro-Winkler similarity between two strings.
  """
  @spec similarity(String.t(), String.t()) :: float()
  def similarity(first_string, second_string) do
    first_normalized = String.downcase(first_string)
    second_normalized = String.downcase(second_string)

    similarity_prepared(
      first_normalized,
      prepare_prefix(first_normalized),
      second_normalized
    )
  end

  @doc false
  @spec similarity_normalized(String.t(), String.t()) :: float()
  def similarity_normalized(first_string, second_string) do
    similarity_prepared(first_string, prepare_prefix(first_string), second_string)
  end

  @doc false
  @spec prepare_prefix(String.t()) :: [String.grapheme()]
  def prepare_prefix(string) do
    take_graphemes(string, @max_prefix_length, [])
  end

  @doc false
  @spec similarity_prepared(String.t(), [String.grapheme()], String.t()) :: float()
  def similarity_prepared(first_string, first_prefix, second_string) do
    jaro = String.jaro_distance(first_string, second_string)

    if jaro > @boost_threshold do
      prefix_length = prefix_length(first_prefix, second_string)
      jaro + prefix_length * @scaling_factor * (1.0 - jaro)
    else
      jaro
    end
  end

  defp take_graphemes(_, 0, graphemes), do: Enum.reverse(graphemes)
  defp take_graphemes("", _, graphemes), do: Enum.reverse(graphemes)

  defp take_graphemes(string, remaining, graphemes) do
    {grapheme, rest} = String.next_grapheme(string)
    take_graphemes(rest, remaining - 1, [grapheme | graphemes])
  end

  defp prefix_length(first_prefix, second_string) do
    matching_prefix_length(first_prefix, second_string, 0)
  end

  defp matching_prefix_length([], _, count), do: count
  defp matching_prefix_length(_, "", count), do: count

  defp matching_prefix_length([first_grapheme | rest], second_string, count) do
    case String.next_grapheme(second_string) do
      {^first_grapheme, remaining_string} ->
        matching_prefix_length(rest, remaining_string, count + 1)

      _ ->
        count
    end
  end
end
