defmodule Mercurial.Mixfile do
  @license """
     Mercurial
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

    [
      apps_path: "apps",
      version: "0.1.1-#{git_sha}",
      git_sha: "#{git_sha}",
      source_url: "https://github.com/TimHughey/mercurial",
      name: "Mercurial",
      deps: deps(),
      aliases: aliases(),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      package: package()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps, do: []

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
     "ecto.seed": ["seed"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end

  defp package do
    [
      files: ["lib", "priv", "LICENSE", "README*", "config", "test"],
      maintainers: ["Tim Hughey"],
      licenses: [@license],
    ]
  end
end
