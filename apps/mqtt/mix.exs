defmodule Mqtt.Mixfile do
  @moduledoc """
  """
  use Mix.Project

  def project do
    [
      app: :mqtt,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Mqtt.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:httpoison, "~> 0.12"},
     {:hackney, "~> 1.9"},
     {:timex, "~> 3.0"},
     {:poison, "~> 3.1"},
     {:distillery, "~> 1.0"},
     {:hulaaki, "~> 0.1.0"},
     {:uuid, "~> 1.1"},
     {:credo, "> 0.0.0", only: [:dev, :test]},
     {:dialyxir, "~> 0.5", only: [:dev], runtime: false}]
  end
end
