defmodule Command.Control do
  @moduledoc """
  """
  require Logger
  use GenServer

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]

  alias Command.Timesync

  #
  # GenServer Startup and Initialization
  #
  def start_link(s) do
    base = [timesync: []]

    defs = %{
      timesync: %{frequency: 60 * 1000, loops: 0, forever: true, log: false, single: false}
    }

    opts = get_env(:mcp, Command.Control, base) |> Enum.into(%{})
    ts_opts = Map.merge(defs.timesync, Enum.into(opts.timesync, %{}))
    opts = Map.put(opts, :timesync, ts_opts)

    s = Map.put(s, :opts, opts)
    s = Map.put(s, :timesync, nil)

    Logger.info(fn -> "start_link() opts: #{inspect(opts)}" end)

    GenServer.start_link(__MODULE__, s, name: __MODULE__)
  end

  def init(s)
      when is_map(s) do
    Logger.info(fn -> "init()" end)

    case Map.get(s, :autostart, false) do
      true -> send_after(self(), {:startup}, 0)
      false -> nil
    end

    {:ok, s}
  end

  #
  # External Functions
  #
  def send_timesync do
    GenServer.call(Command.Control, {:timesync_msg})
  end

  #
  # GenServer Callbacks
  #

  def handle_call({:timesync_msg}, _from, s) do
    r = Timesync.send(s.opts)

    {:reply, {r}, s}
  end

  def handle_info({:startup}, s)
      when is_map(s) do
    s = start_timesync_task(s)

    {:noreply, s}
  end

  def handle_info({ref, result}, %{timesync: %{task: %{ref: timesync_ref}}} = s)
      when is_reference(ref) and ref == timesync_ref do
    s = Map.put(s, :timesync, Map.put(s.timesync, :result, result))

    {:noreply, s}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %{timesync: %{task: %{ref: timesync_ref}}} = s
      )
      when is_reference(ref) and is_pid(pid) do
    s =
      if ref == timesync_ref do
        track =
          Map.put(s.timesync, :exit, reason) |> Map.put(:task, nil)
          |> Map.put(:status, :finished)

        Map.put(s, :timesync, track)
      end

    {:noreply, s}
  end

  defp start_timesync_task(%{opts: opts} = s) do
    track = %{task: Task.async(Timesync, :run, [opts]), status: :started}

    Map.put(s, :timesync, track)
  end

  #
  # Support Functions
  #

  # defp publish_opts(topic, msg)
  # when is_binary(topic) and is_binary(msg) do
  #   [topic: topic, message: msg, dup: 0, qos: 0, retain: 0]
  # end

  # defp config(key)
  # when is_atom(key) do
  #   get_env(:mcp, Command.Control) |> Keyword.get(key)
  # end
end
