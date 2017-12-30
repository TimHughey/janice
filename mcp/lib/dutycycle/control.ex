defmodule Dutycycle.Control do

#    Master Control Program for Wiss Landing
#    Copyright (C) 2016  Tim Hughey (thughey)

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>

  @moduledoc """
  GenServer implementation of Dutycycle controller capable of:
    - controlling a single device
    - to maintain temperature in alignment with reference
  """

  require Logger
  use GenServer
  use Timex

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]

  alias Dutycycle.Control
  alias Dutycycle.CycleTask
  alias Dutycycle.State

  #
  # alias Switch
  # alias Ecto.Changeset
  # import Ecto.Query, only: [from: 2]
  # import Application, only: [get_env: 2]
  # import Keyword, only: [get: 3]
  #
  #
  def start_link(args) do
    Logger.info fn -> "start_link() args: #{inspect(args)}" end
    defs = []

    opts = get_env(:mcp, Dutycycle.Control, defs) |> Enum.into(%{})
    s = Map.merge(%{opts: opts, tasks: %{}}, args)

    GenServer.start_link(__MODULE__, s, name: __MODULE__)
  end

  def init(s) when is_map(s) do
    Logger.info fn -> "init() state: #{inspect(s)}" end

    all_dcs = Dutycycle.all()
    all_switches = Enum.map(all_dcs, fn(x) -> x.device end)

    Logger.info fn -> "setting all switches off at startup " <>
                      "#{inspect(all_switches)}" end

    Enum.each(all_switches, fn(x) -> SwitchState.state(x, false) end)

    Process.flag(:trap_exit, true)

    if s.autostart, do: send_after(self(), {:startup}, 0)

    # opts = [strategy: :one_for_all, name: Dutycycle.CycleTask]
    # Supervisor.init([], opts)

    {:ok, s}
  end

  def terminate(reason, s) do
    all_dcs = Dutycycle.all()
    stop_all(s, all_dcs)

    Logger.info fn -> "terminating with reason #{inspect(reason)}" end
  end

  ####################
  # Public Functions #
  ####################

  def activate_profile(name, profile_name)
  when is_binary(name) and is_binary(profile_name) do
    GenServer.call(Control, {:activate_profile_msg, name, profile_name})
  end

  def disable_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:disable_cycle_msg, name})
  end

  def enable_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:enable_cycle_msg, name})
  end

  def start_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:start_cycle_msg, name})
  end

  def stop_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:stop_cycle_msg, name})
  end

  #######################
  # GenServer callbacks #
  #######################

  def handle_call({:activate_profile_msg, name, profile_name}, _from,
      %{tasks: tasks} = s) do
    tasks = Dutycycle.active_profile(name) |> stop_single(tasks)

    Dutycycle.activate_profile(name, profile_name)

    tasks = Dutycycle.active_profile(name) |> start_single(tasks)

    s = Map.put(s, :tasks, tasks)

    {:reply, {:ok}, s}
  end

  def handle_call({:disable_cycle_msg, name}, _from, %{tasks: tasks} = s) do
    results = Dutycycle.disable(name)
    tasks = stop_single(name, tasks)

    s = Map.put(s, :tasks, tasks)

    Logger.info fn -> "cycle [#{name}] disabled" end

    {:reply, {:ok, results}, s}
  end

  def handle_call({:enable_cycle_msg, name}, _from, %{tasks: tasks} = s) do
    results = Dutycycle.enable(name)
    tasks = start_single(name, tasks)

    s = Map.put(s, :tasks, tasks)

    Logger.info fn -> "cycle [#{name}] enabled" end

    {:reply, {:ok, results}, s}
  end

  def handle_call({:start_cycle_msg, name}, _from, %{tasks: tasks} = s) do
    dc = Dutycycle.active_profile(name)

    tasks = start_single(dc, tasks)

    s = Map.put(s, :tasks, tasks)

    {:reply, {:ok, tasks}, s}
  end

  def handle_call({:stop_cycle_msg, name}, _from, %{tasks: tasks} = s) do

    {result, s} =
      case Map.get(tasks, name) do
        %{task: nil} -> Logger.info fn -> "cycle not running for [#{name}]" end
                       {:not_running, s}

        %{task: task} -> Logger.info fn -> "shutting down cycle for "<>
                                         "[#{inspect(name)}] task: #{inspect(task)}" end
                       new_tasks = stop_single(name, tasks)
                       {:ok, Map.put(s, :tasks, new_tasks)}

        _not_found  -> Logger.info fn -> "cycle [#{name}] is unknown" end
                       {:not_found, s}
      end

    {:reply, {result}, s}
  end

  def handle_info({:startup}, %{tasks: tasks} = s) do
    all_dcs = Dutycycle.all()
    stop_all(s, all_dcs)
    tasks = start_all(all_dcs, tasks)

    s = Map.put(s, :tasks, tasks)

    {:noreply, s}
  end


  def handle_info({ref, result}, %{tasks: tasks} = s)
  when is_reference(ref) do
    Logger.info fn -> "ref: #{inspect(ref)} result: #{inspect(result)}" end
    Logger.info fn -> "tasks: #{tasks}" end

    for %{ref: ^ref} = task <- tasks do
      Logger.info fn -> "cycle for [#{task.name}] ended " <>
                        "with result #{inspect(result)}" end
    end

    {:noreply, s}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{tasks: tasks} = s) do
    Logger.info fn -> "ref: #{inspect(ref)} pid: #{inspect(pid)} " <>
                      "reason: #{reason}\n" <> "tasks: #{tasks}" end

    _tasks =
      # for task <- tasks do
      #   if task.ref == ref do
      #     Logger.info fn -> "cycle for [#{task.name}] down" end
      #     Map.put(task, :ref, nil)
      #   else
      #     task
      #   end
      # end

    # FIXME -- above comprehension needs to return correct map
    # s = Map.put(s, :tasks, tasks)

    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info fn -> ":EXIT message " <>
                       "pid: #{inspect(pid)} reason: #{inspect(reason)}" end

    {:noreply, state}
  end

  defp start_all(list, %{} = tasks) when is_list(list) do
    tasks =
      for %Dutycycle{enable: true} = dc <- list do
        start_single(dc, tasks)
      end |> Enum.reduce(tasks, fn(x, acc) -> Map.merge(acc, x) end)

    Logger.info fn ->
      names = Map.keys(tasks) |>
              Enum.map(fn(x) -> "[#{x}]" end) |>
              Enum.join(" ")

      "start_all(): #{names}" end

    tasks
  end

  defp start_single(nil, %{} = tasks), do: tasks
  defp start_single(%Dutycycle{name: name} = dc, %{} = tasks) do
    task = Map.get(tasks, name, %{task: nil})
    Map.merge(tasks, %{name => start_task(dc, task)})
  end

  defp start_task(%Dutycycle{} = dc, %{task: nil}) do
    task = Task.async(CycleTask, :run, [dc])
    %{task: task}
  end

  defp start_task(%Dutycycle{} = dc, %{task: %Task{}} = task) do
    Logger.warn fn -> "cycle [#{dc.name}] is already started" end
    task
  end

  defp stop_all(%{} = s, list) when is_list(list) do
    # returns a map of tasks
    tasks =
      for %Dutycycle{} = dc <- list do
        asis_task = Map.get(s.tasks, dc.name, %{task: nil})
        State.set_stopped(dc)
        stop_task(asis_task)
        %{dc.name => %{task: nil}}
      end |> Enum.reduce(fn(x, acc) -> Map.merge(acc, x) end)

    Logger.info fn ->
      names = Map.keys(tasks) |>
              Enum.map(fn(x) -> "[#{x}]" end) |>
              Enum.join(" ")

      "stop_all(): #{names}" end

    tasks
  end

  defp stop_single(nil, %{} = t), do: t
  defp stop_single(%Dutycycle{name: name}, %{} = t), do: stop_single(name, t)
  defp stop_single(name, %{} = tasks) when is_binary(name) do
    Logger.info fn -> "stopping cycle [#{name}]" end

    State.set_stopped(name)
    task = Map.get(tasks, name, %{task: nil})
    Map.merge(tasks, %{name => stop_task(task)})
  end


  defp stop_task(%{task: nil}), do: %{task: nil}
  defp stop_task(%{task: %Task{} = task}) do
    Task.shutdown(task)
    %{task: nil}
  end

end
