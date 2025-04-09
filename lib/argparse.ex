defmodule Argparse do
  def parse_args(args) do
    {opts, remaining, _} =
      OptionParser.parse(args,
        switches: [verbose: :boolean, sensitivity: :string, algorithm: :string]
      )

    verbose = Keyword.get(opts, :verbose, false)

    sensitivity =
      case Keyword.get(opts, :sensitivity) do
        nil ->
          1.0

        s when is_binary(s) ->
          s =
            if String.starts_with?(s, ".") do
              "0" <> s
            else
              s
            end

          case Float.parse(s) do
            {value, _} -> value
            :error -> 1.0
          end

        other ->
          other
      end

    algorithm =
      case Keyword.get(opts, :algorithm, "levenshtein") do
        "levenshtein" -> :levenshtein
        "lev" -> :levenshtein
        "jaro_winkler" -> :jaro_winkler
        "jw" -> :jaro_winkler
        _ -> :jaro_winkler
      end

    command = List.first(remaining)
    {verbose, command, sensitivity, algorithm}
  end
end
