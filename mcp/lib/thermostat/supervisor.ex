defmodule Thermostat.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def init(args) do
    Logger.info(fn -> "init()" end)

    ids = Thermostat.all(:ids)

    th_children =
      for id <- ids do
        {Thermostat.Server, Map.put(args, :id, id)}
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Thermostat.Supervisor]
    Supervisor.init(th_children, opts)
  end

  def is_match?(a, name) when is_atom(a) do
    str = Atom.to_string(a)

    String.contains?(str, name)
  end

  def known_servers(match_name \\ "Thermo_ID") do
    children = Supervisor.which_children(Thermostat.Supervisor)

    for {server_name, _pid, _type, _modules} <- children,
        is_match?(server_name, match_name),
        do: server_name
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
end
