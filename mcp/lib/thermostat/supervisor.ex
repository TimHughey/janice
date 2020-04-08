defmodule Thermostat.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def eliminate_child(name) when is_atom(name) do
    children = Supervisor.which_children(__MODULE__)

    deleted =
      for {server, pid, _type, _modules} <- children,
          server === name,
          do: Supervisor.delete_child(__MODULE__, pid)

    if Enum.empty?(deleted), do: :not_found, else: :ok
  end

  def init(args) do
    log = Map.get(args, :log, %{}) |> Map.get(:init, false)

    log &&
      Logger.info(["init() args: ", inspect(args, pretty: true)])

    servers_to_start(args)
    |> Supervisor.init(strategy: :rest_for_one, name: __MODULE__)
  end

  def is_match?(a, name) when is_atom(a) do
    str = Atom.to_string(a)

    String.contains?(str, name)
  end

  def known_servers(match_name \\ "Thermostat_ID") do
    children = Supervisor.which_children(__MODULE__)

    for {server_name, _pid, _type, _modules} <- children,
        is_match?(server_name, match_name),
        do: server_name
  end

  def ping, do: if(is_pid(Process.whereis(__MODULE__)), do: :pong, else: nil)

  def restart_thermostat(name) when is_binary(name) do
    child_id =
      Thermostat.get_by(name: name)
      |> server_name_atom()

    rc = Supervisor.terminate_child(__MODULE__, child_id)

    if rc == :ok,
      do: Supervisor.restart_child(__MODULE__, child_id),
      else: :not_found
  end

  def server_name_atom(%{id: id}),
    do:
      String.to_atom(
        "Thermostat_ID" <> String.pad_leading(Integer.to_string(id), 6, "0")
      )

  def server_name_atom(_), do: :no_server

  def start_link(args) when is_list(args) do
    Supervisor.start_link(__MODULE__, Enum.into(args, %{}), name: __MODULE__)
  end

  defp servers_to_start(%{start_workers: true} = args) do
    for id <- Thermostat.all(:ids),
        do: {Thermostat.Server, Map.put(args, :id, id)}
  end

  defp servers_to_start(_args), do: []
end
