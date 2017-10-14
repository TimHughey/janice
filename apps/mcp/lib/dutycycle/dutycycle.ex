defmodule Mcp.Dutycycle do

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
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  alias Mcp.Dutycycle
  alias Mcp.Repo
  alias Mcp.Switch
  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Application, only: [get_env: 2]
  import Keyword, only: [get: 3]

  @vsn 2
  defmodule State do
    @moduledoc :false

    @kickstarted :kickstarted
    @known_dutycycles :known_dutycycles
    @names :names
    @cycles :cycles
    @ts :ts
    @status :status
    @never :never
    @complete :complete

    defstruct kickstarted: %{@ts => Timex.zero, @status => @never},
      known_dutycycles: %{@ts => Timex.zero, @names => []},
      cycles: %{}

    def set_known_dutycycles(%State{} = state, n) when is_list(n) do
      state = clean_orphans(state, n, state.known_dutycycles.names)

      kn = %{@ts => Timex.now(), @names => n}
      state = %State{state | @known_dutycycles => kn}
      put_cycles(state, n)
    end

    defp put_cycles(%State{} = state, []), do: state

    defp put_cycles(%State{} = state, names) when is_list(names) do
      state |> put_cycles(hd(names)) |> put_cycles(tl(names))
    end

    defp put_cycles(%State{} = state, name) when is_binary(name) do
      new_cycle = %{ts: Timex.now(), status: :new, timer: :nil}
      cycles = Map.put_new(state.cycles, name, new_cycle)

      %State{state | @cycles => cycles}
    end

    defp clean_orphans(%State{} = state, new, old)
    when is_list(new) and is_list(old) do
      clean_orphans(state, (old -- new), :log)
    end

    defp clean_orphans(%State{} = state, [], :log), do: state
    defp clean_orphans(%State{} = state, orphans, :log)
    when is_list(orphans) do
      msg = Enum.join(orphans, ", ")
      Logger.info fn -> "dutycycle detected orphans [#{msg}] -- will clean." end
      clean_orphans(state, orphans)
    end

    defp clean_orphans(%State{} = state, []), do: state
    defp clean_orphans(%State{} = state, orphans)
    when is_list(orphans) do
      state |> clean_orphans(hd(orphans)) |> clean_orphans(tl(orphans))
    end

    defp clean_orphans(%State{} = state, orphan) when is_binary(orphan) do
      cycles = Map.delete(state.cycles, orphan)

      %State{state | @cycles => cycles}
    end

    def known_dutycycles(%State{} = state) do
      state.known_dutycycles.names
    end

    def kickstarted(%State{} = state) do
      %State{state | @kickstarted =>  status_tuple(@complete)}
    end

    def is_kickstarted?(%State{} = state) do
      case state.kickstarted.status do
        @never    -> :false
        @complete -> :true
        actual    -> actual
      end
    end

    defp status_tuple(v), do: ts_tuple(@status, v)
    defp ts_tuple(k, v) when is_atom(k) do
      %{@ts => Timex.now, k => v}
    end
  end

  schema "dutycycles" do
    field :name
    field :description
    field :enable, :boolean
    field :device_sw
    field :device_state, :boolean, default: :false
    field :run_ms, :integer
    field :idle_ms, :integer
    field :state_at, Timex.Ecto.DateTime

    timestamps usec: true
  end

  @known_dutycycles_msg :known_dutycycles_msg

  def start_link(_args) do
    GenServer.start_link(Mcp.Dutycycle, %State{}, name: Mcp.Dutycycle)
  end

  def init(state) do
    state = State.kickstarted(state)
    state = State.set_known_dutycycles(state, get_all_dutycycles())

    auto_populate()
    autostart_ms =
      get_env(:mcp, Mcp.Dutycycle) |> get(:autostart_wait_ms, 1000)
    Process.send_after(self(), {:start}, autostart_ms)

    {:ok, state}
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

  def default_dutycycles do
    [%Dutycycle{name: "buzzer",
       description: "dutycycle test case",
       enable: false, device_sw: "buzzer",
       run_ms: 1000, idle_ms: 60 * 1000},
     %Dutycycle{name: "sump vent",
       description: "sump vent",
       enable: false, device_sw: "sump_vent",
       run_ms: 20 * 60 * 1000, idle_ms: 2 * 60 * 1000},
     %Dutycycle{name: "basement circulation",
       description: "basement circulation fan",
       enable: true, device_sw: "basement_fan",
       run_ms: 15 * 60 * 1000, idle_ms: 60 * 1000},
     %Dutycycle{name: "reefmix rodi slow",
       description: "periodic fill reefmix with rodi water",
       enable: true, device_sw: "reefmix_rodi_valve",
       run_ms: 5 * 60 * 1000, idle_ms: 5 * 60 * 1000},
     %Dutycycle{name: "reefmix rodi fast",
       description: "fill mixtank quickly",
       enable: false, device_sw: "reefmix_rodi_valve",
       run_ms: 60 * 60 * 1000, idle_ms: 5 * 60 * 1000}]
#     %Dutycycle{name: "proxr test", description: "proxr test", enable: true,
#       device_sw: "proxr_test", run_ms: 3*60*1000, idle_ms: 2*60*1000}
  end

  def auto_populate do
    query = from d in Dutycycle, select: d.id
    db_count  = query |> Repo.all() |> Enum.count
    def_count = Enum.count(default_dutycycles())

    dutycycles =
      case db_count do
        x when x < def_count -> default_dutycycles()
        _rest -> []
    end

    for dutycycle <- dutycycles do
      dutycycle |> load() |> persist()
    end |> Enum.count
  end

  defp load(%Dutycycle{name: :nil}), do: :nil
  defp load(%Dutycycle{} = dutycycle) do
    case Repo.get_by Dutycycle, name: dutycycle.name do
      :nil   -> dutycycle
      found  -> found
    end
  end

  defp persist(%Dutycycle{name: :nil}), do: :nil
  defp persist(%Dutycycle{} = dutycycle) do
    dutycycle |> Changeset.change(%{state_at: Timex.now()}) |>
      Changeset.unique_constraint(:name) |> Repo.insert_or_update()
  end

  defp control_device(dutycycle, power)
  when is_boolean(power) do
    Switch.set_state(dutycycle.device_sw, power)
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
      :disabled -> Process.send_after(self(), {:run, name}, 20)
      _ignored -> :nil
    end
  end

  defp stop_cycle_if_active(state, name)
  when is_map(state) and is_binary(name) do
    cycle = state.cycles[name]

    if cycle.timer != :nil do
      Logger.info fn -> "dutycycle [#{name}] timer canceled" end
      Process.cancel_timer(cycle.timer)
    end

    Process.send_after(self(), {:run, name}, 20)
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

    id = Process.send_after(self(), {:idle, dc.name}, dc.run_ms)

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

    id = Process.send_after(self(), {:run, dc.name}, dc.idle_ms)

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

  def handle_info({:start}, %State{} = state) do
    for name <- State.known_dutycycles(state) do
      _ref = Process.send_after(self(), {:run, name}, 3)
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

    Process.send_after(self(), {:routine_check}, routine_check_ms)
  end
end
