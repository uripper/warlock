defmodule Warlock.MixProject do
  use Mix.Project

  def project do
    [
      app: :warlock,
      version: "0.1.4",
      elixir: "~> 1.18",
      escript: [main_module: Warlock],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Warlock.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
