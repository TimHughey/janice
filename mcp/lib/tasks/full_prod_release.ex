defmodule Mix.Tasks.Mcp.Prod.Full.Release do
  @moduledoc """
  Build a fullproduction release and stage for deployment
  """

  @shortdoc "Build and stage a full production release"

  use Mix.Task
  import IO.ANSI, only: [format: 1]

  @impl Mix.Task
  def run(_args) do
    confirm_prod_env()

    Mix.shell().info(build_msg())
    Mix.Task.run("release", ["--quiet"])

    stage_release()
  end

  defp build_msg,
    do:
      format([
        :bright,
        :white,
        "[MCP] ",
        "Building ",
        :green,
        "full ",
        :white,
        "release for ",
        :cyan,
        "prod ",
        :white,
        "environment"
      ])

  defp confirm_prod_env do
    env = Mix.env()

    if env === :prod do
      0
    else
      msg =
        format([
          :bright,
          :white,
          "[MCP] ",
          :yellow,
          "Command must be run in the ",
          :cyan,
          ":prod",
          :yellow,
          " environment."
        ])

      Mix.shell().error(msg)

      msg =
        format([
          :bright,
          :white,
          "[MCP] ",
          :cyan,
          "HINT --> ",
          :green,
          "env MIX_ENV=prod ",
          :white,
          "<cmd>"
        ])

      Mix.shell().info(msg)
      exit({:shutdown, 1})
    end
  end

  defp stage_release do
    config = Mix.Project.config()
    vsn = Keyword.get(config, :version)
    stage_path = Kernel.get_in(config, [:stage_paths, Mix.env()])
    tar_ball = "mcp.tar.gz"

    src_file =
      Path.join([
        "_build",
        "#{Mix.env()}",
        "rel",
        "mcp",
        "releases",
        "#{vsn}",
        tar_ball
      ])

    dest_file =
      Path.join([
        stage_path,
        tar_ball
      ])

    System.cmd("cp", [src_file, dest_file])

    msg =
      format([
        :bright,
        :white,
        "[MCP] ",
        "Staged ",
        :green,
        tar_ball,
        :white,
        " to ",
        :yellow,
        stage_path,
        :white,
        " for ",
        :cyan,
        "prod ",
        :white,
        "deployment"
      ])

    Mix.shell().info(msg)
  end
end
