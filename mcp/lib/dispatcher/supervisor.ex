defmodule Dispatcher.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor
  import Application, only: [fetch_env: 2]

  def init(_args) do
    Logger.info(fn -> "init()" end)

    autostart =
      case fetch_env(:mcp, :build_env) do
        {:ok, "test"} -> false
        _anything_else -> true
      end

    children = [
      {Dispatcher.InboundMessage, %{autostart: autostart}}
      # Starts a worker by calling: Dispatcher.Worker.start_link(arg)
      # {Dispatcher.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dispatcher.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
end
