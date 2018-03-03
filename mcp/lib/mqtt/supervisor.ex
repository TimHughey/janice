defmodule Mqtt.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def init(args) do
    Logger.info(fn -> "init()" end)

    # List all child processes to be supervised
    children = [
      {Mqtt.Client, args},
      {MessageSave, args},
      {Mqtt.InboundMessage, args}
    ]

    # Starts a worker by calling: Mqtt.Worker.start_link(arg)
    # {Mqtt.Worker, arg},

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Mqtt.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
end
