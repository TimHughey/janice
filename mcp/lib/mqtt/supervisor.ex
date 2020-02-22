defmodule Mqtt.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def child_spec(args),
    do: %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :supervisor
    }

  def init(args) do
    Logger.info(["init() args: ", inspect(args, pretty: true)])

    # List all child processes to be supervised
    children = [
      {MessageSave, args},
      {Mqtt.Client, args},
      {Mqtt.InboundMessage, args}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Mqtt.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
end
