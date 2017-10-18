defmodule Dispatcher.Mixfile do
  @moduledoc """
  """
  use Mix.Project

  def project do
    [
      app: :dispatcher,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Dispatcher.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:command, in_umbrella: true},
     # {:mcp, in_umbrella: true},
     {:timex, "~> 3.0"},
     {:poison, "~> 3.1"},
     {:distillery, "~> 1.0"},
     {:credo, "> 0.0.0", only: [:dev, :test]}]
  end
end
