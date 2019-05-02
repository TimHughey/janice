defmodule Mix.Tasks.Mcp.Deploy do
  use Mix.Task

  @shortdoc "Deploy the current release"

  @impl Mix.Task
  def run(args) do
    msg = "env: #{inspect(Mix.env())} " <> Enum.join(args, " ")

    Mix.shell().info(msg)

    config = Mix.Project.config()
    deploy_path = Kernel.get_in(config, [:deploy_paths, Mix.env()])

    Mix.shell().info(inspect(config, pretty: true))
    Mix.Generator.create_directory(deploy_path)
  end
end
