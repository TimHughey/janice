defmodule Mercurial.Mixfile do
  @moduledoc """
  """
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      source_url: "https://github.com/TimHughey/mercurial",
      name: "Mercurial",
      deps: deps(),
      aliases: aliases(),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do []
    # [{:httpoison, "~> 0.12"},
    #  {:hackney, "~> 1.9"},
    #  {:timex, "~> 3.0"},
    #  {:poison, "~> 3.1"},
    #  {:postgrex, "~> 0.13"},
    #  {:ecto, "~> 2.1"},
    #  {:timex_ecto, "~> 3.1"},
    #  {:distillery, "~> 1.0"},
    #  {:hulaaki, "~> 0.1.0"},
    #  {:uuid, "~> 1.1"},
    #  {:instream, "~> 0.16"},
    #  {:credo, "> 0.0.0", only: [:dev, :test]},
    #  {:dialyxir, "~> 0.5", only: [:dev], runtime: false}]
  end

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
     "ecto.seed": ["run apps/mcp/priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end
end
