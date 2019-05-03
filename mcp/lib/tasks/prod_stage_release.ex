defmodule Mix.Tasks.Mcp.Prod.Stage.Release do
  @moduledoc """
  Stage the tarball for a Production full release
  """

  @shortdoc "Stage MCP Production tarball"

  use Mix.Task
  import IO.ANSI, only: [format: 1]

  @shortdoc "Stage a production build for deploy"

  @impl Mix.Task
  def run(_args) do
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
        "Staged production ",
        :green,
        tar_ball,
        :white,
        " to ",
        :green,
        stage_path
      ])

    Mix.shell().info(msg)
  end
end
