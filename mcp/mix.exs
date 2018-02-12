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
    Mix file defining Mercurial Web
  """

  use Mix.Project

  def project do
    {result, _rc} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
    git_sha = String.trim(result)

    {result, _rc} = System.cmd("git", ["rev-parse", "--short", "mcr-stable"])
    mcr_sha = String.trim(result)

    [
      app: :mcp,
      version: "0.1.1-#{git_sha}",
      elixir: "~> 1.5",
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
      git_sha: "#{git_sha}",
      mcr_sha: "#{mcr_sha}"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    args = [
      build_env: "#{Mix.env()}",
      git_sha: project() |> Keyword.get(:git_sha),
      mcr_sha: project() |> Keyword.get(:mcr_sha)
    ]

    [
      extra_applications: [
        :logger,
        :runtime_tools,
        :ueberauth_identity,
        :ueberauth_github,
        :lager
      ],
      mod: {Mcp.Application, args}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.0"},
      {:poison, "~> 3.1", override: true},
      {:instream, "~> 0.16"},
      {:hackney, "~> 1.1"},
      {:poolboy, "~> 1.5"},
      {:httpoison, "~> 0.12"},
      {:postgrex, "~> 0.13"},
      {:ecto, "~> 2.1"},
      {:timex_ecto, "~> 3.1"},
      {:emqttc, github: "emqtt/emqttc"},
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
      {:distillery, "~> 1.0"},
      {:credo, "> 0.0.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "ecto.seed": ["seed"],
      "ecto.setup": ["ecto.create", "ecto.migrate --log-sql", "ecto.seed"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
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
end
