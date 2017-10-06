defmodule Timeseries.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

alias Timeseries.Influx

def start(_type, _args) do
  build_env =
    Application.get_env(:timeseries, Timeseries.Application) |>
      Keyword.get(:build_env)

  autostart =
  case build_env do
    "dev" -> true
    _     -> false
  end

  _initial_state = %{autostart: autostart}

  # List all child processes to be supervised
  children = [
    Influx.child_spec
  ]

  opts = [strategy: :one_for_one, name: Timeseries.Supervisor]
  Supervisor.start_link(children, opts)
end

end
