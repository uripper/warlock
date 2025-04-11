defmodule Argparse do
  @moduledoc """
  Parse command‑line arguments for **Warlock**.
  """

  # =================
  # Default values
  # =================
  @default_sensitivity 1.0
  @default_threshold 0.75
  @default_matches 5
  @spec parse_args([String.t()]) ::
          {boolean, String.t() | nil, float, atom, float, pos_integer, [String.t()], [String.t()]}
  def parse_args(args) do
    {opts, remaining, _} = OptionParser.parse(args, switches: switches())

    handle_help_and_version(opts)

    verbose = Keyword.get(opts, :verbose, false)
    sensitivity = parse_sensitivity(opts[:sensitivity])
    algorithm = parse_algorithm(opts[:algorithm])
    threshold = parse_threshold(opts[:threshold])
    num_matches = parse_matches(opts[:matches])
    ignore = parse_ignore_option(opts[:ignore])
    ignoredir = parse_ignore_option(opts[:ignoredir])
    command = List.first(remaining)

    {verbose, command, sensitivity, algorithm, threshold, num_matches, ignore, ignoredir}
  end

  # ==========================
  # Command line switches
  # ==========================
  defp switches do
    [
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
  end

  # ==================
  # Help and version
  # ==================
  defp handle_help_and_version(opts) do
    cond do
      opts[:help] -> print_help_and_exit()
      opts[:version] -> print_version_and_exit()
      true -> :ok
    end
  end

  @spec print_help_and_exit() :: no_return()
  defp print_help_and_exit do
    IO.puts("""
    Usage: warlock [options] command

    Options:
      --help           Show this help message
      --verbose        Enable verbose mode
      --sensitivity    Set sensitivity (float), default: #{@default_sensitivity}
      --algorithm      levenshtein | jaro_winkler, default: jaro_winkler
      --threshold      Float 0‑1, default: #{@default_threshold}. Lower → more matches
      --ignore         Comma‑separated extensions to ignore
      --ignoredir      Comma‑separated directories to ignore
      --matches        Number of matches to display, default: #{@default_matches}
      --version        Show version information
    """)

    System.halt(0)
  end

  @spec print_version_and_exit() :: no_return()
  defp print_version_and_exit do
    IO.puts(Warlock.version())
    System.halt(0)
  end

  # =============
  # Sensitivity
  # =============
  defp parse_sensitivity(nil), do: @default_sensitivity

  defp parse_sensitivity(str) when is_binary(str) do
    str
    |> ensure_leading_zero()
    |> Float.parse()
    |> case do
      {v, _} -> v
      :error -> @default_sensitivity
    end
  end

  defp parse_sensitivity(other), do: other

  # ============
  # Algorithm
  # ============
  defp parse_algorithm(nil), do: :jaro_winkler
  defp parse_algorithm("levenshtein"), do: :levenshtein
  defp parse_algorithm("lev"), do: :levenshtein
  defp parse_algorithm("jaro_winkler"), do: :jaro_winkler
  defp parse_algorithm("jw"), do: :jaro_winkler
  defp parse_algorithm(_), do: :jaro_winkler

  # ============
  # Threshold
  # ============
  defp parse_threshold(nil), do: @default_threshold

  defp parse_threshold(str) when is_binary(str) do
    value =
      str
      |> ensure_leading_zero()
      |> Float.parse()
      |> case do
        {v, ""} when v >= 0.0 and v <= 1.0 -> v
        _ -> log_invalid(:threshold, str, @default_threshold)
      end

    value
  end

  defp parse_threshold(_), do: @default_threshold

  # ========
  # Matches
  # ========
  defp parse_matches(nil), do: @default_matches

  defp parse_matches(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} when n >= 1 ->
        n

      _ ->
        IO.puts(:stderr, "--matches must be an integer ≥ 1")
        System.halt(1)
    end
  end

  # =========================================
  # Ignore directories and ignore extensions
  # =========================================
  defp parse_ignore_option(nil), do: []
  defp parse_ignore_option(""), do: []
  defp parse_ignore_option(str), do: String.split(str, ",")

  # =========================================
  # Ensure leading zero for float parsing
  # =========================================
  defp ensure_leading_zero("." <> rest), do: "0." <> rest
  defp ensure_leading_zero(other), do: other

  # ===================
  # Log invalid values
  # ===================
  defp log_invalid(name, value, default) do
    require Logger
    Logger.warning("Invalid #{name} value: #{value}. Using default #{default}")
    default
  end
end
