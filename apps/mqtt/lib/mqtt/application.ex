defmodule Mqtt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    build_env =
      Application.get_env(:mqtt, Mqtt.Application) |> Keyword.get(:build_env)

    autostart =
    case build_env do
      "dev" -> true
      _     -> false
    end

    initial_state = %{autostart: autostart}

    # List all child processes to be supervised
    children = [
      {Mqtt.Client, initial_state},
      {Mqtt.Dispatcher, initial_state}]
      # Starts a worker by calling: Mqtt.Worker.start_link(arg)
      # {Mqtt.Worker, arg},

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mqtt.Supervisor]
    Supervisor.start_link(children, opts)

  end
end
