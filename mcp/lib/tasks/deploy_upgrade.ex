defmodule Mix.Tasks.Mcp.Deploy.Upgrade do
  @moduledoc """
  Deploy an upgrade release

  The release will be deployed to the base path specified in the
  project configuration :deploy_paths keyword list in preparation
  for an upgrade.
  """

  use Mix.Task
  import IO.ANSI, only: [format: 1]

  @shortdoc "Deploy the current release"

  @impl Mix.Task
  def run(_args) do
    # msg =
    #   format([
    #     :bright,
    #     :white,
    #     "[MCP] ",
    #     "Deploying upgrade release for ",
    #     :bright,
    #     :cyan,
    #     "#{Mix.env()}",
    #     :normal,
    #     :white,
    #     " env"
    #   ])
    #
    # Mix.Shell.IO.info(msg)

    config = Mix.Project.config()
    vsn = Keyword.get(config, :version)
    deploy_base = Kernel.get_in(config, [:deploy_paths, Mix.env()])
    tar_ball = "mcp.tar.gz"

    deploy_path = Path.join([deploy_base, "releases", vsn])

    System.cmd("mkdir", ["-p", deploy_path])

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
        deploy_path,
        tar_ball
      ])

    System.cmd("cp", [src_file, dest_file])

    msg =
      format([
        :bright,
        :white,
        "[MCP] ",
        "Deployed ",
        :bright,
        :green,
        dest_file,
        :white,
        " using environment ",
        :cyan,
        "#{Mix.env()}"
      ])

    Mix.Shell.IO.info(msg)
  end
end
