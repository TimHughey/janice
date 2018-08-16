defmodule Mcp.Mixfile do
  @license """
       Master Control Program
       Copyright (C) 2017  Tim Hughey (thughey)

       This program is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.

       This program is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.

       You should have received a copy of the GNU General Public License
       along with this program.  If not, see <http://www.gnu.org/licenses/>
  """
  @moduledoc """
    Mix file defining Master Control Program Web
  """

  use Mix.Project

  def project do
    [
      app: :mcp,
      version: "0.1.2-#{sha_head()}",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description: description(),
      escript: escript_config(),
      sha_head: "#{sha_head()}",
      sha_mcr_stable: "#{sha_mcr_stable()}",
      test_coverage: test_coverage()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :runtime_tools,
        :ueberauth_identity,
        :ueberauth_github,
        :parse_trans
      ],
      mod: {Mcp.Application, args()}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:instream, "~> 0.17"},
      {:hackney, "~> 1.1"},
      {:poolboy, "~> 1.5"},
      {:httpoison, "~> 0.12"},
      {:postgrex, "~> 0.13"},
      {:ecto, "~> 2.1"},
      {:timex_ecto, "~> 3.1"},
      {:emqttc, github: "rabbitmq/emqttc", tag: "remove-logging"},
      {:uuid, "~> 1.1"},
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:guardian, "~> 1.0"},
      {:ueberauth, "~> 0.4"},
      {:ueberauth_github, "~> 0.4"},
      {:ueberauth_identity, "~> 0.2"},
      # {:distillery, "~> 2.0"},
      {:distillery, github: "bitwalker/distillery"},
      {:quantum, "~> 2.2"},
      {:credo, "> 0.0.0", only: [:dev, :test]},
      {:coverex, "~> 1.4.10", only: :test}
    ]
  end

  defp aliases do
    [
      "ecto.seed": ["seed"],
      "ecto.setup": ["ecto.create", "ecto.migrate --log-sql", "ecto.seed"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp args do
    [
      build_env: "#{Mix.env()}",
      sha_head: sha_head(),
      sha_mcr_stable: sha_mcr_stable()
    ]
  end

  defp description do
    "Master Control Program for Wiss Landing"
  end

  defp package do
    [
      files: ["lib", "priv", "LICENSE", "README*", "config", "test"],
      maintainers: ["Tim Hughey"],
      licenses: [@license]
    ]
  end

  defp escript_config, do: [main_module: Mcp]

  defp sha_head do
    {result, _rc} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
    String.trim(result)
  end

  defp sha_mcr_stable do
    {result, _rc} = System.cmd("git", ["rev-parse", "--short", "mcr-stable"])
    String.trim(result)
  end

  defp test_coverage do
    [
      tool: Coverex.Task,
      ignore_modules: [
        Mcp.Chamber,
        Mcp.Chamber.AutoPopulate,
        Mcp.Chamber.Device,
        Mcp.Chamber.RunState,
        Mcp.Chamber.ServerState,
        Mcp.IExHelpers,
        Fact.Celsius.Fields,
        Fact.Celsius.Tags,
        Fact.EngineMetric.Fields,
        Fact.EngineMetric.Tags,
        Fact.Fahrenheit.Fields,
        Fact.Fahrenheit.Tags,
        Fact.DevMetric.Fields,
        Fact.DevMetric.Tags,
        Fact.FreeRamStat.Fields,
        Fact.FreeRamStat.Tags,
        Fact.LedFlashes.Fields,
        Fact.LedFlashes.Tags,
        Fact.RelativeHumidity.Fields,
        Fact.RelativeHumidity.Tags,
        Fact.RunMetric.Fields,
        Fact.RunMetric.Tags,
        Fact.StartupAnnouncement.Fields,
        Fact.StartupAnnouncement.Tags,
        Mix.Tasks.Seed,
        Seed.Chambers,
        Seed.Dutycycles,
        Seed.Mixtanks,
        Seed.Sensors,
        Seed.Switches,
        Web.Router.Helpers,
        Repo
      ]
    ]
  end
end
