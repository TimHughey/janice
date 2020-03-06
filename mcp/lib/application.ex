defmodule Mcp.Application do
  @moduledoc false

  use Application
  require Logger
  import Application, only: [get_env: 2, get_env: 3, put_env: 3]
  import Keyword, only: [has_key?: 2]

  @log_opts get_env(:mcp, Mcp.Application, []) |> Keyword.get(:log, [])

  def start(_type, args) do
    log = Keyword.get(@log_opts, :init, true)

    log &&
      Logger.info(["start() ", inspect(args, pretty: true)])

    build_env = Keyword.get(args, :build_env, "dev")

    put_env(:mcp, :build_env, build_env)

    children =
      for i <- get_env(:mcp, :sup_tree) do
        if is_tuple(i), do: i, else: get_env(:mcp, i)
      end
      |> List.flatten()

    log &&
      Logger.info(["will start: ", inspect(children, pretty: true)])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :rest_for_one,
      name: Mcp.Supervisor,
      max_restarts: 100,
      max_seconds: 5
    ]

    # only start the Supervisor if the database password is set
    if get_env(:mcp, Repo, []) |> has_key?(:password) do
      Supervisor.start_link(children, opts)
    else
      {:error, :no_db_password}
    end
  end
end
