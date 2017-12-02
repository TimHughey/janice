defmodule Mercurial.Mixfile do
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
      start_permanent: Mix.env == :prod
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
end
