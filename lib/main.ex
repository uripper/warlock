defmodule Warlock do
  @moduledoc """
  A smarter 'which' command with fuzzy matching.

  Usage:
      warlock [--verbose] [--sensitivity=VALUE] <command>
  """
  # Public entry point called by the escript runtime.
  def main(args) do
    case Argparse.parse_args(args) do
      {verbose, command, sensitivity, algorithm} when not is_nil(command) ->
        Witch.witch(command, verbose, sensitivity, algorithm)

      _ ->
        IO.puts("Usage: warlock [--verbose] [--sensitivity=VALUE] <command>")
    end
  end
end
