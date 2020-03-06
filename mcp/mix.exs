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
    Mix file defining Master Control Program
  """

  use Mix.Project

  def project do
    [
      app: :mcp,
      version: "0.1.46",
      elixir: "~> 1.10",
      deps: deps(),
      releases: releases(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      aliases: aliases(),
      package: package(),
      description: description(),
      escript: escript_config(),
      test_coverage: test_coverage(),
      deploy_paths: deploy_paths(),
      stage_paths: stage_paths()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Mcp.Application, args()},
      extra_applications: [
        :logger,
        :runtime_tools,
        :parse_trans
      ]
    ]
  end

  def deploy_paths,
    do: [
      dev: "/tmp/janice/dev",
      test: "/tmp/janice/test",
      prod: "/usr/local/janice"
    ]

  def stage_paths,
    do: [prod: "/tmp"]

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
      {:httpoison, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_sql, "~> 3.1"},
      {:tortoise, "~> 0.9"},
      {:uuid, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:quantum, "~> 2.2"},
      {:scribe, "~> 0.10"},
      {:msgpax, "~> 2.0"},
      {:credo, "> 0.0.0", only: [:dev, :test], runtime: false},
      {:coverex, "~> 1.0", only: :test}
      # {:phoenix, "~> 1.4.0"},
      # {:phoenix_pubsub, "~> 1.0"},
      # {:phoenix_ecto, "~> 4.0"},
      # {:phoenix_html, "~> 2.10"},
      # {:phoenix_live_reload, "~> 1.2", only: :dev},
      # {:plug_cowboy, "~> 2.0"},
      # {:plug, "~> 1.7"},
      # {:guardian, "~> 1.0"},
      # {:ueberauth, "~> 0.4"},
      # {:ueberauth_github, "~> 0.4"},
      # {:ueberauth_identity, "~> 0.2"},
    ]
  end

  defp aliases do
    [
      "ecto.migrate": [
        "ecto.migrate",
        "ecto.dump --dump-path priv/repo/structure-#{Mix.env()}.sql"
      ],
      "ecto.setup": ["ecto.create", "ecto.load", "ecto.migrate"],
      "ecto.reset": [
        "ecto.drop",
        "ecto.create",
        "ecto.load --dump-path priv/repo/structure-#{Mix.env()}.sql",
        "ecto.migrate",
        "ecto.dump --dump-path priv/repo/structure-#{Mix.env()}.sql"
      ],
      "mcp.deps.update": [
        "local.hex --if-missing --force",
        "deps.get",
        "deps.clean --unused"
      ]
      # test: ["ecto.create --quiet", "ecto.load", "ecto.migrate", "test"]
    ]
  end

  # defp aliases do
  #   [
  #     "ecto.seed": ["seed"],
  #     "ecto.setup": ["ecto.create", "ecto.migrate --log-sql", "ecto.seed"],
  #     "ecto.reset": ["ecto.drop", "ecto.setup"]
  #   ]
  # end

  defp args do
    [
      build_env: "#{Mix.env()}",
      git_vsn: "#{git_describe()}"
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

  defp git_describe do
    {result, _rc} = System.cmd("git", ["describe"])
    String.trim(result)
  end

  defp test_coverage do
    [
      tool: Coverex.Task,
      ignore_modules: [
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
        Repo
      ]
    ]
  end

  defp sym_link_data(release) do
    {:ok, home} = System.fetch_env("HOME")

    %{
      build_path:
        Path.join([
          home,
          "devel",
          "janice",
          "mcp",
          "_build",
          Atom.to_string(Mix.env())
        ]),
      tarball: "#{release.name}-#{release.version}.tar.gz",
      sym_link: "mcp.tar.gz"
    }
  end

  defp sym_link_to_tar_rm(release) do
    link = sym_link_data(release)

    System.cmd("rm", ["-f", link.tarball],
      cd: link.build_path,
      stderr_to_stdout: true
    )

    release
  end

  defp sym_link_to_tar(release) do
    link = sym_link_data(release)

    System.cmd("ln", ["-sf", link.tarball, link.sym_link],
      cd: link.build_path,
      stderr_to_stdout: true
    )

    release
  end

  defp releases do
    [
      mcp: [
        include_erts: true,
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        cookie: "augury-kinship-swain-circus",
        steps: [&sym_link_to_tar_rm/1, :assemble, :tar, &sym_link_to_tar/1]
      ]
    ]
  end
end
