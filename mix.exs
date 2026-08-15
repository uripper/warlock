defmodule Warlock.MixProject do
  use Mix.Project

  @spec project() :: keyword()
  def project do
    [
      app: :warlock,
      version: "0.1.4",
      elixir: "~> 1.20",
      escript: [main_module: Warlock, name: "warlock_beam"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  @spec application() :: keyword()
  def application do
    [
      extra_applications: [:logger],
      mod: {Warlock.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false}
    ]
  end
end
