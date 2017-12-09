defmodule Mqtt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do

    autostart =
      case Application.fetch_env(:mqtt, :build_env) do
        {:ok, "dev"}   -> true
        {:ok, "prod"}  -> true
        _anything_else -> Logger.warn fn ->
                            ":mqtt config for :build_env missing!"
                          end
                          false
      end

    initial_state = %{autostart: autostart}

    # List all child processes to be supervised
    children = [
      {Mqtt.Client, initial_state}
    ]
      # Starts a worker by calling: Mqtt.Worker.start_link(arg)
      # {Mqtt.Worker, arg},

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mqtt.Supervisor]
    Supervisor.start_link(children, opts)

  end
end
