defmodule Argparse do
  @moduledoc """
  Parse command‑line arguments for **Warlock**.
  """

  alias Warlock.CliOptions

  @spec parse_args([String.t()]) :: {String.t() | nil, CliOptions.t()}
  def parse_args(args) do
    {options, remaining, _} =
      OptionParser.parse(args,
        switches: switches()
      )

    handle_help_and_version(options)
    {List.first(remaining), CliOptions.from_keyword(options)}
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
    defaults = CliOptions.defaults()

    IO.puts("""
    Usage: warlock [options] command

    Options:
      --help           Show this help message
      --verbose        Enable verbose mode
      --sensitivity    Set sensitivity (float), default: #{defaults.sensitivity}
      --algorithm      levenshtein | jaro_winkler, default: jaro_winkler
      --threshold      Float 0‑1, default: #{defaults.threshold}. Lower → more matches
      --ignore         Comma‑separated extensions to ignore
      --ignoredir      Comma‑separated directories to ignore
      --matches        Number of matches to display, default: #{defaults.matches}
      --version        Show version information
    """)

    System.halt(0)
  end

  @spec print_version_and_exit() :: no_return()
  defp print_version_and_exit do
    IO.puts(Warlock.version())
    System.halt(0)
  end
end
