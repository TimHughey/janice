defmodule Dutycycle do

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
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Application, only: [get_env: 2]
  import Keyword, only: [get: 3]
  import Process, only: [cancel_timer: 1, send_after: 3]

  @vsn 3

  schema "dutycycles" do
    field :name
    field :description
    field :enable, :boolean
    field :device
    has_one :state, Dutycycle.State
    has_many :mode, Dutycycle.Mode

    timestamps usec: true
  end

  @known_dutycycles_msg :known_dutycycles_msg

  def start_link(args) do
    GenServer.start_link(McpDutycycle, args, name: Mcp.Dutycycle)
  end

  @spec init(Map.t) :: {:ok, Map.t}
  def init(s) when is_map(s) do
    state =
      %State{} |>
      State.kickstarted() |>
      State.set_known_dutycycles(get_all_dutycycles()) |>
      Kernel.struct(s)

    autostart_ms =
      get_env(:mcp, Mcp.Dutycycle) |> get(:autostart_wait_ms, 1000)

    case Map.get(s, :autostart, false) do
      true  -> if autostart_ms > 0 do
                 send_after(self(), {:start}, autostart_ms)
               end
      false -> nil
    end

    Logger.info("init()")

    {:ok, state}
  end

  @manual_start_msg {:manual_start}
  def manual_start do
    GenServer.call(Mcp.Dutycycle, @manual_start_msg)
  end

  def stop do
    GenServer.stop(Mcp.Dutycycle)
  end

  def disabled_cycles do
    GenServer.call(Mcp.Dutycycle, {:get_disabled_cycles})
  end

  def known_cycles do
    GenServer.call(Mcp.Dutycycle, @known_dutycycles_msg)
  end

  @spec add(map) :: %Mcp.Dutycycle{}
  def add(dutycycle)
  when is_map(dutycycle) do
    Repo.insert(dutycycle)
  end

  defp control_device(dutycycle, power)
  when is_boolean(power) do
    SwitchState.state(dutycycle.device_sw, power, :lazy)
    update = %{state_at: Timex.now(), device_state: power}
    dutycycle |> Changeset.change(update) |> Repo.update()
  end

  defp get_all_dutycycles do
    query = from d in Dutycycle, select: d.name
    query |> Repo.all()
  end

  defp disable_cycle(dc, state) do
    status = state.cycles[dc.name].status

    if status == :running or status == :idling do
      Logger.info fn -> "switching off device for dutycycle: #{dc.name}" end
      _changeset = control_device(dc, :false)
    end

    update_status(state, dc.name, :disabled)
  end

  defp do_disabled_cycles(state) do
    cycles = Map.keys(state.cycles)
    Enum.filter(cycles, fn(x) -> state.cycles[x][:status] == :disabled end)
  end

  defp start_cycle_if_disabled(state, name)
  when is_map(state) and is_binary(name) do
    cycle = state.cycles[name]

    case cycle.status do
      :disabled -> send_after(self(), {:run, name}, 20)
      _ignored -> :nil
    end
  end

  defp stop_cycle_if_active(state, name)
  when is_map(state) and is_binary(name) do
    cycle = state.cycles[name]

    if cycle.timer != :nil do
      Logger.info fn -> "dutycycle [#{name}] timer canceled" end
      cancel_timer(cycle.timer)
    end

    send_after(self(), {:run, name}, 20)
  end

  defp run_cycle(:nil, %State{} = state), do: state
  defp run_cycle(%Dutycycle{enable: false} = dc, %State{} = state) do
    disable_cycle(dc, state)
  end

  defp run_cycle(%Dutycycle{enable: true} = dc, %State{} = state) do
    case dc.run_ms do
      x when x > 0  -> control_device(dc, :true)
      x when x == 0 -> control_device(dc, :false)
      _rest         -> control_device(dc, :false)
    end

    id = send_after(self(), {:idle, dc.name}, dc.run_ms)

    update_status(state, dc.name, :running, id)
  end

  defp idle_cycle(:nil, %State{} = state), do: state
  defp idle_cycle(%Dutycycle{enable: false} = dc, %State{} = state) do
    disable_cycle(dc, state)
  end

  defp idle_cycle(%Dutycycle{enable: true} = dc, %State{} = state) do
    case dc.idle_ms do
      x when x > 0  -> control_device(dc, :false)
      x when x == 0 -> control_device(dc, :true)
      _rest         -> control_device(dc, :false)
    end

    id = send_after(self(), {:run, dc.name}, dc.idle_ms)

    update_status(state, dc.name, :idling, id)
  end

  def handle_call(:shutdown, _from, state) do
    {:stop, :graceful, state}
  end

  def handle_call({:get_disabled_cycles}, _from, state) do
    {:reply, do_disabled_cycles(state), state}
  end

  def handle_call(@known_dutycycles_msg, _from, state) do
    known = State.known_dutycycles(state)
    {:reply, known, state}
  end

  def handle_call(@manual_start_msg, _from, state) do
    send_after(self(), {:start}, 0)

    {:reply, [], state}
  end

  def handle_info({:start}, %State{} = state) do
    Logger.info fn -> "startup()" end

    for name <- State.known_dutycycles(state) do
      Logger.info fn -> "sending run msg for dutycycle #{name}" end
      _ref = send_after(self(), {:run, name}, 3)
    end

    schedule_routine_check()

    {:noreply, state}
  end

  def handle_info({:routine_check}, state) do
    names = get_all_dutycycles()
    state = State.set_known_dutycycles(state, names)

    for name <- names do
      dc = Repo.get_by(Mcp.Dutycycle, [name: name])

      case dc.enable do
        :true  -> start_cycle_if_disabled(state, name)
        :false -> stop_cycle_if_active(state, name)
      end
    end

    schedule_routine_check()

    {:noreply, state}
  end

  def handle_info({:run, name}, state) do
    dc = get_by_name(name)

    state = run_cycle(dc, state)

    {:noreply, state}
  end

  def handle_info({:idle, name}, state) do
    dc = get_by_name(name)

    state = idle_cycle(dc, state)

    {:noreply, state}
  end

  def code_change(old_vsn, state, _extra) do
    Logger.warn fn -> "#{__MODULE__}: code_change from old vsn #{old_vsn}" end

    {:ok, state}
  end

  defp get_by_name(name), do: Repo.get_by(Mcp.Dutycycle, [name: name])

  defp update_status(state, name, status, timer_id \\ :nil)
  when is_map(state) and is_binary(name) and is_atom(status) do
    cycle = %{name => %{ts: Timex.now(), status: status, timer: timer_id}}

    %State{state | cycles: Map.merge(state.cycles, cycle)}
  end

  defp schedule_routine_check do
    routine_check_ms =
      get_env(:mcp, Mcp.Dutycycle) |> get(:routine_check_ms, 1000)

    send_after(self(), {:routine_check}, routine_check_ms)
  end
end
