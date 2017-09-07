defmodule Mqtt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Mqtt.Worker.start_link(arg)
      # {Mqtt.Worker, arg},
      {Mqtt.Client, []}      
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mqtt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
