defmodule Mcp.Application do
  @moduledoc false

  use Application
  require Logger
  import Application, only: [fetch_env: 2, get_env: 3]
  import Keyword, only: [has_key?: 2]

  def start(_type, args) do

    Logger.info fn -> "start() args: #{inspect(args)}" end

    autostart =
    case fetch_env(:mcp, :build_env) do
      {:ok, "test"}  -> false
      _anything_else -> true
    end

    initial = %{autostart: autostart}

    # List all child processes to be supervised
    children = [
      {Repo, []},
      {Fact.Supervisor, initial},
      {Mqtt.Supervisor, initial},
      {Dispatcher.Supervisor, initial},
      {Command.Supervisor, initial},
      {Janitor, initial},
      {Mixtank, initial},
      {Web.Supervisor, initial}

      # {Mcp.SoakTest, initial},
      # {Mcp.Dutycycle, initial},
      # {Mcp.Chamber, initial}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mcp.Supervisor]

    # only start the Supervisor if the database password is set
    if get_env(:mcp, Repo, []) |> has_key?(:password) do
      Supervisor.start_link(children, opts)
    else
      {:error, :no_db_password}
    end
  end
end
