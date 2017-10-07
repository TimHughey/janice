defmodule Fact.Mixfile do
  @moduledoc """
  """
  use Mix.Project

  def project do
    [
      app: :fact,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      build_embedded: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Fact.Application, []},
      # applications: [:instream, :hackney, :poolboy, :poison]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:instream, "~> 0.16"},
     {:hackney, "~> 1.1"},
     {:poison,  "~> 2.0 or ~> 3.0"},
     {:poolboy, "~> 1.5"}]
  end
end
