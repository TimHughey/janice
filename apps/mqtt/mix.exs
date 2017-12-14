defmodule Mqtt.Mixfile do
  @license """
     MQTT Client for Mercurial
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
  """
  use Mix.Project

  def project do
    {result, _exit_code} = System.cmd("git", ["rev-parse", "--short", "HEAD"])

    git_sha = String.trim(result)

    [app: :mqtt,
      version: "0.1.0-#{git_sha}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package()]
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
     {:credo, "> 0.0.0", only: [:dev, :test]}]
  end

  defp package do
    [
      files: ["lib", "priv", "LICENSE", "README*", "config", "test"],
      maintainers: ["Tim Hughey"],
      licenses: [@license],
    ]
  end
end
