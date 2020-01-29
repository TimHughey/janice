defmodule Thermostat.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def eliminate_thermostat(name) when is_atom(name) do
    children = Supervisor.which_children(Thermostat.Supervisor)

    deleted =
      for {server, pid, _type, _modules} <- children,
          server === name,
          do: Supervisor.delete_child(__MODULE__, pid)

    if Enum.empty?(deleted), do: :not_found, else: :ok
  end

  def init(args) do
    Logger.info(fn -> "init()" end)

    ids = Thermostat.all(:ids)

    th_children =
      for id <- ids do
        {Thermostat.Server, Map.put(args, :id, id)}
      end

    c =
      if Map.get(args, :start_servers, false) == true,
        do: th_children,
        else: []

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Thermostat.Supervisor]
    Supervisor.init(c, opts)
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

  def ping, do: if(is_pid(Process.whereis(__MODULE__)), do: :pong, else: nil)

  def restart_thermostat(name) when is_binary(name) do
    child_id =
      Thermostat.get_by(name: name)
      |> Thermostat.Server.server_name_atom()

    rc = Supervisor.terminate_child(__MODULE__, child_id)

    if rc == :ok,
      do: Supervisor.restart_child(__MODULE__, child_id),
      else: :not_found
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
end
