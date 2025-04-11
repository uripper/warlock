defmodule Argparse do
  def parse_args(args) do
    # ===============================================================
    # Parse Command-Line Options
    # ===============================================================
    {opts, remaining, _} =
      OptionParser.parse(args,
        switches: [
          verbose: :boolean,
          sensitivity: :string,
          algorithm: :string,
          help: :boolean,
          threshold: :string,
          version: :boolean,
          matches: :string,
          ignore: :string,
          ignoredir: :string
        ]
      )

    # ===============================================================
    # Handle Help and Version Flags
    # ===============================================================
    if opts[:help] do
      IO.puts("Usage: [options] command")
      IO.puts("Options:")
      IO.puts("  --help           Show this help message")
      IO.puts("  --verbose        Enable verbose mode")
      IO.puts("  --sensitivity    Set sensitivity (float value), Default: 1.0")
      IO.puts(
        "  --algorithm      Set the algorithm (levenshtein, jaro_winkler, etc.), Default: jaro_winkler"
      )
      IO.puts(
        "  --threshold      Set the threshold (value between 0 and 1), Default: 0.75. Lower values yield more matches."
      )
      IO.puts("  --ignore         Ignore specific extensions (comma-separated list), Default: none")
      IO.puts("  --ignoredir      Ignore specific directories (comma-separated list), Default: none")
      IO.puts("  --matches        Set the number of matches to display, Default: 5")
      IO.puts("  --version        Show version information")
      System.halt(0)
    end

    if Keyword.get(opts, :version, false) do
      IO.puts(Warlock.version())
      System.halt(0)
    end

    # ===============================================================
    # Process Basic Options
    # ===============================================================
    verbose = Keyword.get(opts, :verbose, false)

    # Sensitivity Option
    default_sensitivity = 1.0
    sensitivity =
      case Keyword.get(opts, :sensitivity) do
        nil ->
          default_sensitivity

        s when is_binary(s) ->
          s =
            if String.starts_with?(s, ".") do
              "0" <> s
            else
              s
            end

          case Float.parse(s) do
            {value, _} -> value
            :error -> default_sensitivity
          end

        other ->
          other
      end

    # Algorithm Option
    algorithm =
      case Keyword.get(opts, :algorithm, "jaro_winkler") do
        "levenshtein" -> :levenshtein
        "lev" -> :levenshtein
        "jaro_winkler" -> :jaro_winkler
        "jw" -> :jaro_winkler
        _ -> :jaro_winkler
      end

    # Threshold Option
    default_threshold = 0.75
    threshold =
      case Keyword.get(opts, :threshold) do
        nil ->
          default_threshold

    t when is_binary(t) ->
      t =
        if String.starts_with?(t, ".") do
          "0" <> t
        else
          t
        end
      # Parse threshold value and provide feedback if it is invalid.
      case Float.parse(t) do
        {value, ""} when value >= 0.0 and value <= 1.0 ->
          value
        _ ->
          require Logger
          Logger.warning("Invalid threshold value: #{t}. Using default #{default_threshold}")
          default_threshold
      end

          case Float.parse(t) do
            {value, _} ->
              if value >= 0.0 and value <= 1.0 do
                value
              else
                default_threshold
              end

            :error ->
              default_threshold
          end

        _ ->
          default_threshold
      end

    # Matches Option (Number of suggestions)
    matches = Keyword.get(opts, :matches, "5")

    num_matches =
      case Integer.parse(matches) do
        {parsed, ""} when parsed >= 1 ->
          parsed

        {_parsed, ""} ->
          IO.puts(:stderr, "Matches must be at least 1.")
          System.halt(1)

        _ ->
          IO.puts("Please enter a valid number.")
          System.halt(1)
      end

    # ===============================================================
    # Process List Options (ignore and ignoredir)
    # ===============================================================
    ignore =
      case Keyword.get(opts, :ignore, "") do
        "" -> []
        s -> String.split(s, ",")
      end

    ignoredir =
      case Keyword.get(opts, :ignoredir, "") do
        "" -> []
        s -> String.split(s, ",")
      end

    # ===============================================================
    # Get Command Argument
    # ===============================================================
    command = List.first(remaining)

    {verbose, command, sensitivity, algorithm, threshold, num_matches, ignore, ignoredir}
  end
end
