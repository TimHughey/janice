defmodule Mixtank.Control do
  @moduledoc """
  """

  require Logger
  use GenServer
  use Timex

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]

  alias Mixtank.Control
  alias Mixtank.TankTask
  alias Mixtank.State

  def start_link(args) do
    Logger.info(fn -> "start_link() args: #{inspect(args)}" end)
    defs = [control_temp_secs: 27]

    opts = get_env(:mcp, Mixtank.Control, defs) |> Enum.into(%{})
    s = Map.merge(%{opts: opts, tasks: %{}}, args)

    GenServer.start_link(__MODULE__, s, name: __MODULE__)
  end

  def init(s) when is_map(s) do
    Logger.info(fn -> "init() state: #{inspect(s)}" end)

    Process.flag(:trap_exit, true)

    if s.autostart, do: send_after(self(), {:startup}, 0)

    # opts = [strategy: :one_for_all, name: Mixtank.TankTask]
    # Supervisor.init([], opts)

    {:ok, s}
  end

  def terminate(reason, %{opts: opts} = s) do
    all_mts = Mixtank.all()
    stop_all(s, all_mts, opts)

    Logger.info(fn -> "terminating with reason #{inspect(reason)}" end)
  end

  ####################
  # Public Functions #
  ####################

  def activate_profile(name, profile_name)
      when is_binary(name) and is_binary(profile_name) do
    GenServer.call(Control, {:activate_profile_msg, name, profile_name})
  end

  def change_profile(name, profile, opts) do
    GenServer.call(Control, {:change_profile_msg, name, profile, opts})
  end

  def disable_tank(name) when is_binary(name) do
    GenServer.call(Control, {:disable_tank_msg, name})
  end

  def enable_tank(name) when is_binary(name) do
    GenServer.call(Control, {:enable_tank_msg, name})
  end

  def start_tank(name) when is_binary(name) do
    GenServer.call(Control, {:start_tank_msg, name})
  end

  def stop_tank(name) when is_binary(name) do
    GenServer.call(Control, {:stop_tank_msg, name})
  end

  #######################
  # GenServer callbacks #
  #######################

  def handle_call({:activate_profile_msg, name, profile_name}, _from, s) do
    s = do_activate_profile(name, profile_name, s)

    {:reply, {:ok}, s}
  end

  def handle_call({:disable_tank_msg, name}, _from, %{tasks: tasks, opts: opts} = s) do
    mt = Mixtank.get(name)
    results = Mixtank.disable(mt)
    tasks = stop_single(mt, tasks, opts)

    s = Map.put(s, :tasks, tasks)

    Logger.info(fn -> "tank [#{name}] disabled" end)

    {:reply, {:ok, results}, s}
  end

  def handle_call({:enable_tank_msg, name}, _from, %{tasks: tasks, opts: opts} = s) do
    results = Mixtank.enable(name)
    mt = Mixtank.active_profile(name)
    tasks = start_single(mt, tasks, opts)

    s = Map.put(s, :tasks, tasks)

    Logger.info(fn -> "tank [#{name}] enabled" end)

    {:reply, {:ok, results}, s}
  end

  def handle_call({:start_tank_msg, name}, _from, %{tasks: tasks, opts: opts} = s) do
    mt = Mixtank.active_profile(name)

    tasks = start_single(mt, tasks, opts)

    s = Map.put(s, :tasks, tasks)

    {:reply, {:ok, tasks}, s}
  end

  def handle_call({:stop_tank_msg, name}, _from, %{tasks: tasks, opts: opts} = s) do
    {result, s} =
      case Map.get(tasks, name) do
        %{task: nil} ->
          Logger.warn(fn -> "tank not running for [#{name}]" end)
          {:not_running, s}

        %{task: task} ->
          Logger.info(fn ->
            "shutting down tank for " <> "[#{inspect(name)}] task: #{inspect(task)}"
          end)

          new_tasks =
            Mixtank.get(name)
            |> stop_single(tasks, opts)

          {:ok, Map.put(s, :tasks, new_tasks)}

        _not_found ->
          Logger.warn(fn -> "tank [#{name}] is unknown" end)
          {:not_found, s}
      end

    {:reply, {result}, s}
  end

  def handle_info({:startup}, %{tasks: tasks, opts: opts} = s) do
    all_mts = Mixtank.all()
    stop_all(s, all_mts, opts)

    active_mts = Mixtank.all_active()
    tasks = start_all(active_mts, tasks, opts)

    s = Map.put(s, :tasks, tasks)

    {:noreply, s}
  end

  def handle_info({ref, result}, %{tasks: tasks} = s)
      when is_reference(ref) do
    Logger.debug(fn -> "ref: #{inspect(ref)} result: #{inspect(result)}" end)
    Logger.debug(fn -> "tasks: #{tasks}" end)

    for %{ref: ^ref} = task <- tasks do
      Logger.debug(fn ->
        "tank task for [#{task.name}] ended " <> "with result #{inspect(result)}"
      end)
    end

    {:noreply, s}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{tasks: tasks} = s) do
    Logger.debug(fn ->
      "ref: #{inspect(ref)} pid: #{inspect(pid)} " <>
        "reason: #{reason}\n" <> "tasks: #{inspect(tasks)}"
    end)

    tasks = Enum.filter(tasks, fn x -> x.ref != ref end)

    s = Map.put(s, :tasks, tasks)

    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info(fn -> ":EXIT message " <> "pid: #{inspect(pid)} reason: #{inspect(reason)}" end)

    {:noreply, state}
  end

  defp do_activate_profile(name, profile, %{tasks: tasks, opts: opts} = s) do
    tasks =
      Mixtank.get(name)
      |> stop_single(tasks, opts)

    Mixtank.activate_profile(name, profile)

    tasks =
      Mixtank.active_profile(name)
      |> start_single(tasks, opts)

    Map.put(s, :tasks, tasks)
  end

  defp start_all(list, %{} = tasks, opts) when is_list(list) do
    Logger.debug(fn -> "begin start_all()" end)

    tasks =
      for %Mixtank{enable: true} = mt <- list do
        start_single(mt, tasks, opts)
      end
      |> Enum.reduce(tasks, fn x, acc -> Map.merge(acc, x) end)

    Logger.info(fn ->
      keys = Map.keys(tasks)

      names =
        if Enum.empty?(keys),
          do: "** NONE **",
          else:
            Enum.map(keys, fn x -> "[#{x}]" end)
            |> Enum.join(" ")

      "start_all(): #{names}"
    end)

    tasks
  end

  defp start_single(nil, %{} = tasks, _opts), do: tasks

  defp start_single(%Mixtank{name: name} = mt, %{} = tasks, opts) do
    task = Map.get(tasks, name, %{task: nil})
    Map.merge(tasks, %{name => start_task(mt, task, opts)})
  end

  defp start_task(%Mixtank{profiles: []} = mt, task, _opts) do
    Logger.warn(fn -> "[#{mt.name}] has no active profile, will not start" end)
    task
  end

  defp start_task(%Mixtank{} = mt, %{task: nil}, opts) do
    task = Task.async(TankTask, :run, [mt, opts])
    %{task: task}
  end

  defp start_task(%Mixtank{} = mt, %{task: %Task{}} = task, _opts) do
    Logger.warn(fn -> "tank [#{mt.name}] is already started" end)
    task
  end

  defp stop_all(%{} = s, list, opts) when is_list(list) do
    Logger.debug(fn -> "begin stop_all()" end)
    # returns a map of tasks
    tasks =
      for %Mixtank{} = mt <- list do
        asis_task = Map.get(s.tasks, mt.name, %{task: nil})
        State.set_stopped(mt)
        stop_task(asis_task, opts)
        stop_tank_cycles(mt, opts)
        %{mt.name => %{task: nil}}
      end
      |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)

    Logger.info(fn ->
      keys = Map.keys(tasks)

      names =
        if Enum.empty?(keys),
          do: "** NONE **",
          else:
            Enum.map(keys, fn x -> "[#{x}]" end)
            |> Enum.join(" ")

      "stop_all(): #{names}"
    end)

    tasks
  end

  defp stop_tank_cycles(%Mixtank{} = mt, _opts) do
    Dutycycle.Control.disable_cycle(mt.pump)
    Dutycycle.Control.disable_cycle(mt.air)
    Dutycycle.Control.disable_cycle(mt.heater)
    Dutycycle.Control.disable_cycle(mt.fill)
    Dutycycle.Control.disable_cycle(mt.replenish)
  end

  defp stop_single(nil, %{} = t, _opts), do: t

  defp stop_single(%Mixtank{name: name} = mt, %{} = t, opts) do
    stop_tank_cycles(mt, opts)
    stop_single(name, t, opts)
  end

  defp stop_single(name, %{} = tasks, opts) when is_binary(name) do
    Logger.debug(fn -> "stopping tank [#{name}]" end)

    State.set_stopped(name)
    task = Map.get(tasks, name, %{task: nil})
    Map.merge(tasks, %{name => stop_task(task, opts)})
  end

  defp stop_task(%{task: nil}, _opts), do: %{task: nil}

  defp stop_task(%{task: %Task{} = task}, _opts) do
    Task.shutdown(task)
    %{task: nil}
  end
end
