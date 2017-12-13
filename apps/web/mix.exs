defmodule Web.Mixfile do
  @license """
     Phoenix / Web for Mercurial
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
    {result, _exit_code} = System.cmd("git", ["rev-parse", "--short", "HEAD"])

    git_sha = String.trim(result)

    [app: :web,
      version: "0.0.1-#{git_sha}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps(),
      package: package()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Web.Application, []},
      extra_applications: [:logger, :runtime_tools, :ueberauth_identity,
                            :ueberauth_github]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
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
      {:poison, "~> 3.0", override: true},
      {:mcp, in_umbrella: true}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, we extend the test task to create and migrate the database.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end

  defp package do
    [
      files: ["lib", "priv", "LICENSE", "README*", "config", "test"],
      maintainers: ["Tim Hughey"],
      licenses: [@license],
    ]
  end
end
