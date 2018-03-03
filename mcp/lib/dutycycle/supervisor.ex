defmodule Dutycycle.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def init(args) do
    Logger.info(fn -> "init()" end)

    # List all child processes to be supervised
    children = [
      {Dutycycle.Control, args},
      {Mixtank.Control, args}
    ]

    # Starts a worker by calling: Mqtt.Worker.start_link(arg)
    # {Mqtt.Worker, arg},

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Dutycycle.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
end
