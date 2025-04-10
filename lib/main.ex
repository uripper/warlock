defmodule Warlock do
  @moduledoc """
  A smarter 'which' command with fuzzy matching.

  Usage:
      warlock [--verbose] [--sensitivity=VALUE] <command>
  """
  # Public entry point called by the escript runtime.
  @version Mix.Project.config()[:version]

  def version do
    @version
  end

  def main(args) do
    case Argparse.parse_args(args) do
      {verbose, command, sensitivity, algorithm, threshold, num_matches} when not is_nil(command) ->
        Witch.witch(command, verbose, sensitivity, algorithm, threshold, num_matches)

      _ ->
        IO.puts("Usage: warlock [--verbose] [--threshold=0-1.0] [--algorithm=[\"lev\", \"jw\"]] <command>")
    end
  end
end
