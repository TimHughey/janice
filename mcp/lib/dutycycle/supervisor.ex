defmodule Dutycycle.Supervisor do
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
    Logger.info(["init() args: ", inspect(args, pretty: true)])

    servers_to_start(args)
    |> Supervisor.init(strategy: :one_for_one, name: __MODULE__)
  end

  def is_match?(a, name) when is_atom(a) do
    str = Atom.to_string(a)

    String.contains?(str, name)
  end

  def known_servers(match_name \\ "Duty_ID") do
    children = Supervisor.which_children(__MODULE__)

    for {server_name, pid, _type, _modules} <- children,
        is_match?(server_name, match_name) do
      {server_name, pid}
    end
  end

  def ping, do: if(is_pid(Process.whereis(__MODULE__)), do: :pong, else: nil)

  def restart_dutycycle(name) when is_binary(name) do
    {_dc, child_id} = Dutycycle.Server.server_name(name)

    rc = Supervisor.terminate_child(__MODULE__, child_id)

    if rc == :ok,
      do: Supervisor.restart_child(__MODULE__, child_id),
      else: :not_found
  end

  def server_name_atom(%{id: id}),
    do:
      String.to_atom(
        "Duty_ID" <> String.pad_leading(Integer.to_string(id), 6, "0")
      )

  def server_name_atom(_), do: :no_server

  def start_child(%{id: id, start: _, log: log} = spec) when is_atom(id) do
    {rc, pid} = Supervisor.start_child(__MODULE__, spec)

    if rc == :ok,
      do:
        log &&
          Logger.info([
            "started child ",
            inspect(id, pretty: true)
          ]),
      else:
        Logger.warn([
          "failed to start child ",
          inspect(id, pretty: true),
          " ",
          inspect(rc, pretty: true)
        ])

    {rc, pid}
  end

  def start_child(catchall),
    do:
      Logger.warn(["start_child() bad args: ", inspect(catchall, pretty: true)])

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  defp servers_to_start(%{start_servers: true} = args) do
    for id <- Dutycycle.all(:ids),
        do: {Dutycycle.Server, Map.put(args, :id, id)}
  end

  defp servers_to_start(_args), do: []
end
