defmodule Command.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    build_env =
      Application.get_env(:command, Command.Application) |>
        Keyword.get(:build_env)

    autostart =
    case build_env do
      "dev"   -> true
      "prod"  -> true
      _       -> false
    end

    initial_state = %{autostart: autostart}
    children = [
      {Command.Control, initial_state}
      # Starts a worker by calling: Command.Worker.start_link(arg)
      # {Command.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Command.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
