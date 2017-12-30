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
  import Process, only: [cancel_timer: 1, send_after: 3]

  alias Dutycycle.Control
  alias Dutycycle.CycleTask

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

  def terminate(reason, _state) do
    Logger.info fn -> "terminating with reason #{inspect(reason)}" end
  end

  def start_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:start_cycle_msg, name})
  end

  def stop_cycle(name) when is_binary(name) do
    GenServer.call(Control, {:stop_cycle_msg, name})
  end

  def handle_call({:start_cycle_msg, name}, _from, %{tasks: tasks} = s) do
    dc = Dutycycle.active_mode(name)

    task = start_single(dc, tasks)

    task =
      case task do
        {:not_found}  -> %{}
        started_task  -> started_task
      end

    all_tasks = Map.merge(tasks, task)

    s = Map.put(s, :tasks, all_tasks)

    {:reply, {:ok, task}, s}
  end

  def handle_call({:stop_cycle_msg, name}, _from, %{tasks: tasks} = s) do

    {result, s} =
      case Map.get(tasks, name) do
        %{ref: nil} = t -> Logger.info fn ->
                             "cycle not running for [#{name}]" end
                           {:not_running, s}
        %{ref: ref} = t -> Logger.info fn ->
                             "shutting down cycle for [#{inspect(name)}] " <>
                             "ref #{inspect(ref)}" end
                           # Supervisor.terminate_child(Dutycycle.Supervisor, ref)
                           Task.shutdown(ref)
                           new_tasks = Map.merge(tasks, %{name => %{ref: nil}})
                           {:ok, Map.put(s, :tasks, new_tasks)}
        _not_found     -> Logger.info fn -> "cycle [#{name}] is unknown" end
                          {:not_found, s}
      end

    {:reply, {result}, s}
  end

  def handle_info({:startup}, s) do
    all_dcs = Dutycycle.all()
    tasks = start_all(all_dcs)

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

    tasks =
      for task <- tasks do

        if task.ref == ref do
          Logger.info fn -> "cycle for [#{task.name}] down" end
          Map.put(task, :ref, nil)
        else
          task
        end
      end

    s = Map.put(s, :tasks, tasks)

    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info fn -> ":EXIT message " <>
                       "pid: #{inspect(pid)} reason: #{inspect(reason)}" end

    {:noreply, state}
  end

  defp start_all(list) when is_list(list) do

    for %Dutycycle{enable: true} = dc <- list do
      Logger.info fn -> "start_all #{dc.name}" end

      start_single(dc, :force)
    end |> Enum.reduce(fn(x, acc) -> Map.merge(acc, x) end)
  end

  defp start_single(nil, %{} = tasks), do: {:not_found}

  defp start_single(%Dutycycle{name: name} = dc, %{} = tasks) do

    task = Map.get(tasks, name)

    cond do
      nil == task         -> start_single(dc, :force)
      %{ref: nil} == task -> start_single(dc, :force)
      true                -> Logger.warn fn ->
                              "cycle [#{name}] is already started" end
                             tasks
    end
  end

  defp start_single(%Dutycycle{} = dc, :force) do
    ref = Task.async(CycleTask, :run, [dc])
    %{dc.name => %{ref: ref}}
  end

end
