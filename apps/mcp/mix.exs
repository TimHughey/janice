
defmodule Mcp.Mixfile do
  @license """
     Master Control Program for Wiss Landing
     Copyright (C) 2016  Tim Hughey (thughey)

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
    Mix file defining the Master Control Program (MCP)
  """

  use Mix.Project

  def project do
    [app: :mcp,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     description: description(),
     package: package(),
     elixir: "~> 1.5",
     compilers: [:elixir, :app],
     # compilers: [:proxr, :elixir, :app],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     escript: escript_config(),
     deps: deps()]
  end

  # Configuration for the OTP application
  def application do
    applications_by_env(Mix.env)
  end

  defp applications_by_env(:dev) do
    [mod: {Mcp, []},
      applications:
        [:runtime_tools, :httpoison, :hackney, :timex, :poison, :postgrex,
          :ecto, :timex_ecto, :distillery]
    ]
  end

  defp applications_by_env(_) do
    [mod: {Mcp, []},
      applications:
        [:runtime_tools, :httpoison, :hackney, :timex, :poison, :postgrex,
          :ecto, :timex_ecto, :elixir_ale, :distillery]]
  end

  defp deps do
    [{:httpoison, "~> 0.12"},
     {:hackney, "~> 1.9"},
     {:timex, "~> 3.0"},
     {:poison, "~> 3.1"},
     {:postgrex, "~> 0.13"},
     {:ecto, "~> 2.1"},
     {:timex_ecto, "~> 3.1"},
     {:elixir_ale, "~> 0.7.0", [only: [:prod, :test]]},
     {:distillery, "~> 1.0"},
     {:credo, "> 0.0.0", only: [:dev, :test]}]
  end

  defp description do
    "Master Control Program for Wiss Landing"
  end

  defp package do
    [
      files: ["lib", "priv", "LICENSE", "README*", "config", "test"],
      maintainers: ["Tim Hughey"],
      licenses: [@license],
    ]
  end

  defp escript_config do
  [main_module: Mcp]
  end
end

defmodule Mix.Tasks.Compile.Proxr do
  alias Mix.Project
  @moduledoc :false

  @doc "Compiles proxr port binary"
  def run(_) do

    # bit of a hack here to allow compilation under MacOS
    if Mix.env() == :dev do
      Mix.Shell.IO.cmd("make priv/proxr")
    else
      0 = Mix.Shell.IO.cmd("make priv/proxr")
    end

    Project.build_structure()
    :ok
  end
end
