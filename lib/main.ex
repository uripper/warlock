defmodule Warlock do
  @moduledoc """
  A smarter 'which' command with fuzzy matching.

  Usage:
      warlock [--verbose] [--sensitivity=VALUE] <command>
  """
  # Public entry point called by the escript runtime.
  @version Mix.Project.config()[:version]

  @spec version() :: String.t()
  def version do
    @version
  end

  @spec main([String.t()]) :: String.t() | nil | :ok
  def main(args) do
    args
    |> Argparse.parse_args()
    |> run()
  end

  defp run({command, search_options}) when is_binary(command) do
    Witch.witch(command, search_options)
  end

  defp run(_),
    do:
      IO.puts(
        ~s(Usage: warlock [--verbose] [--threshold=0-1.0] [--algorithm=["lev", "jw"]] <command>)
      )
end
