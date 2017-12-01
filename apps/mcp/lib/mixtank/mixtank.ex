defmodule Mcp.Mixtank do

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
  GenServer implementation of Mixtank controller.

  Provides various capabilities:
    - controlling a water pump and air pump (run time and idle time)
    - heat tank to match reference temperature
  """

  @vsn 1

  require Logger
  use GenServer
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  alias Mcp.Mixtank
  alias Mcp.Repo
  alias Mcp.Sensor
  alias Mcp.Switch
  #alias Mcp.Influx.Position
  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Application, only: [get_env: 2]
  import Keyword, only: [get: 2]
  import Process, only: [send_after: 3]

  defmodule State do
    @moduledoc """
    Provides the state of the Mixtank GenServer.
    """

    @kickstarted :kickstarted
    @known_mixtanks :known_mixtanks
    @tanks :tanks
    @air :air
    @pump :pump
    @heater :heater
    @control_temp :control_temp
    @next_timer :next_timer

    @ts :ts
    @status :status
    @names :names
    @count :count
    @never :never
    @complete :complete
    @running :running
    @idling :idling
    @disabled :disabled
    @ok :ok

    defstruct kickstarted: %{@ts => Timex.zero, @status => @never},
      autostart: false,
      known_mixtanks: %{@ts => Timex.zero, @names => [], @count => 0},
      tanks: %{}

    # tanks map sample:
    # "sample" => %{@air => %{}, @pump => %{}, @heater => %{}}}

    @spec kickstarted(%State{}) :: %State{}
    def kickstarted(%State{} = state) do
      %State{state | @kickstarted => status_tuple(@complete)}
    end

    @spec is_kickstarted?(%State{}) :: atom
    def is_kickstarted?(%State{} = state) do
      case state.kickstarted.status do
        @never    -> :false
        @complete -> :true
        actual    -> actual
      end
    end

    @spec set_known_mixtanks(%State{}, names :: list) :: %State{}
    def set_known_mixtanks(%State{} = state, names) when is_list(names) do
      km = %{@ts => Timex.now(), @names => names, @count => Enum.count(names)}
      state = %State{state | @known_mixtanks => km}
      add_tanks(state, names)
    end

    @spec add_tanks(%State{}, []) :: %State{}
    defp add_tanks(%State{} = state, []), do: state

    @spec add_tanks(%State{}, tanks :: list) :: %State{}
    defp add_tanks(%State{} = state, tanks) when is_list(tanks) do
      state = add_tank(state, hd(tanks))
      add_tanks(state, tl(tanks))
    end

    @spec add_tanks(%State{}, name :: binary) :: %State{}
    defp add_tank(%State{} = state, name) when is_binary(name) do
      now = Timex.now()

      air = %{@ts => now, @status => @never, @next_timer => :nil}
      pump = %{@ts => now, @status => @never, @next_timer => :nil}
      heater = %{@ts => now, @status => @never, @next_timer => :nil}
      control_temp = %{@ts => now, @status => @never, @next_timer => :nil}

      new_tank = %{@air => air, @pump => pump,
                    @heater => heater, @control_temp => control_temp}

      tanks = Map.put_new(state.tanks, name, new_tank)
      %State{state | @tanks => tanks}
    end

    @spec known_mixtanks(%State{}) :: list
    def known_mixtanks(%State{} = state) do
      state.known_mixtanks.names
    end

    @spec set_device_status(%State{}, binary, atom, atom, reference) :: %State{}
    defp set_device_status(%State{} = state, name, device, status, timer)
    when is_binary(name) and is_atom(device) and
    is_atom(status) and (is_reference(timer) or timer == :nil) do

      active_timer = Map.get(state.tanks[name][device], @next_timer)
      cancel_timer_if_disabled(status, active_timer)

      new = %{@ts => Timex.now(), @status => status, @next_timer => timer}
      tank = %{state.tanks[name] | device => new}
      tanks = %{state.tanks | name => tank}
      %State{state | @tanks => tanks}
    end

    @spec cancel_timer_if_disabled(atom, reference) :: nil
    defp cancel_timer_if_disabled(@disabled, timer)
    when is_reference(timer) do
      Process.cancel_timer(timer)
    end

    @spec cancel_timer_if_disabled(atom, nil) :: nil
    defp cancel_timer_if_disabled(_status, _reference), do: :nil

    def set_pump_active(%State{} = state, name, timer)
    when is_binary(name) and is_reference(timer) or timer == :nil do
      set_device_status(state, name, @pump, @running, timer)
    end

    def set_pump_inactive(%State{} = state, name) when is_binary(name) do
      set_pump_inactive(state, name, :nil)
    end
    def set_pump_inactive(%State{} = state, name, timer)
    when is_binary(name) and is_reference(timer) or timer == :nil do
      set_device_status(state, name, @pump, @idling, timer)
    end

    def set_pump_disabled(%State{} = state, name) when is_binary(name) do
      set_device_status(state, name, @pump, @disabled, :nil)
    end

    def set_air_active(%State{} = state, name, timer)
    when is_binary(name) and is_reference(timer) or timer == :nil do
      set_device_status(state, name, @air, @running, timer)
    end

    def set_air_inactive(%State{} = state, name) when is_binary(name) do
      set_air_inactive(state, name, :nil)
    end
    def set_air_inactive(%State{} = state, name, timer)
    when is_binary(name) and is_reference(timer) or timer == :nil do
      set_device_status(state, name, @air, @idling, timer)
    end

    def set_air_disabled(%State{} = state, name) when is_binary(name) do
      set_device_status(state, name, @air, @disabled, :nil)
    end

    def set_heat_status(%State{} = state, name, position)
    when is_binary(name) and is_atom(position) do

      status =
        case position do
          :true  -> @running
          :false -> @idling
        end

      set_device_status(state, name, @heater, status, :nil)
    end
    def set_heat_active(%State{} = state, name) when is_binary(name) do
      set_heat_status(state, name, :true)
    end

    def set_heat_inactive(%State{} = state, name) when is_binary(name) do
      set_heat_status(state, name, :false)
    end

    def set_heat_disabled(%State{} = state, name) when is_binary(name) do
      set_device_status(state, name, @heater, @disabled, :nil)
    end

    def set_control_temp_timer(%State{} = state, name, timer)
    when is_binary(name) and is_reference(timer) do
      set_device_status(state, name, @control_temp, @ok, timer)
    end
    def set_control_temp_timer(%State{} = state, name, timer)
    when is_binary(name) and timer == :nil do
      set_device_status(state, name, @control_temp, @disabled, timer)
    end

    def set_control_temp_disabled(%State{} = state, name) when is_binary(name) do
      active_timer = state.tanks[name][@control_temp].next_timer

      if active_timer != :nil do
        Process.cancel_timer(active_timer)
      end

      set_device_status(state, name, @control_temp, @disabled, :nil)
    end

    def tank_disabled?(%State{} = state, name) when is_binary(name) do
      devices = Map.keys(state.tanks[name])

      Enum.all?(devices, fn(x) -> dev_disabled?(state, name, x) end)
    end

    defp dev_disabled?(%State{} = state, name, dev) do
      case state.tanks[name][dev].status do
        @disabled  -> :true
        @never     -> :true
        _other     -> :false
      end
    end

    def tank_enabled?(%State{} = state, name) when is_binary(name) do
      devices = Map.keys(state.tanks[name])

      Enum.all?(devices, fn(x) -> dev_enabled?(state, name, x) end)
    end

    defp dev_enabled?(%State{} = state, name, dev) do
      case state.tanks[name][dev].status do
        @running  -> :true
        @idling   -> :true
        @ok       -> :true
        _other    -> :false
      end
    end

    defp status_tuple(v), do: ts_tuple(@status, v)
    defp ts_tuple(k, v) when is_atom(k) do
      %{@ts => Timex.now, k => v}
    end

  end

  schema "mixtanks" do
    field :name
    field :description
    field :enable, :boolean, default: false
    field :sensor
    field :ref_sensor
    field :heat_sw
    field :heat_state, :boolean, default: :false
    field :air_sw
    field :air_state, :boolean, default: :false
    field :air_run_ms, :integer
    field :air_idle_ms, :integer
    field :pump_sw
    field :pump_state, :boolean, default: :false
    field :pump_run_ms, :integer
    field :pump_idle_ms, :integer
    field :state_at, Timex.Ecto.DateTime

    timestamps usec: true
  end

  @init_msg {:init}
  @pump_off_msg :pump_off
  @pump_on_msg :pump_on
  @air_off_msg :air_off
  @air_on_msg :air_on
  @control_temp_msg :control_temperature
  @activate_msg :activate
  @manage_msg :manage
  @shutdown_msg :shutdown
  @manual_control_msg :manual_control

  @doc """
  Traditional implemenation of start_link
  """
  def start_link(args) do
    GenServer.start_link(Mcp.Mixtank, args, name: Mcp.Mixtank)
  end

  @spec init(Map.t) :: {:ok, Map.t}
  def init(s) when is_map(s) do
    autostart_ms = config(:autostart_wait_ms)

    case Map.get(s, :autostart, false) do
      true  -> if autostart_ms > 0 do
                 send_after(self(), @init_msg, autostart_ms)
               end
      false -> nil
    end

    state = Kernel.struct(%State{}, s)

    {:ok, state}
  end

  def stop do
    GenServer.stop(Mcp.Mixtank)
  end

  defp load(%Mixtank{name: :nil}), do: :nil
  defp load(name) when is_binary(name) do
    mixtank = %Mixtank{name: name}
    load(mixtank)
  end
  defp load(%Mixtank{} = mixtank) do
    # try to load the Mixtank, if not found return the mixtank passed in
    case Repo.get_by Mixtank, name: mixtank.name do
      :nil   -> mixtank
      found  -> found
    end
  end

  # defp persist(%Mixtank{name: :nil}), do: :nil
  # defp persist(%Mixtank{} = mixtank) do
  #   cs = Changeset.change(mixtank, state_at: Timex.now())
  #   cs = Changeset.unique_constraint(cs, :name)
  #
  #   Repo.insert_or_update cs
  # end

  #defp enable_by_name(%State{} = state, :nil), do: state
  #defp enable_by_name(%State{} = state, name) when is_binary(name) do
  #  mixtank = load(name)
  #  update = %{enable: true}
  #  Changeset.change(mixtank, update) |> Repo.update()
  #  state
  #end

  #defp disable_by_name(%State{} = state, :nil), do: state
  #defp disable_by_name(%State{} = state, name) when is_binary(name) do
  #  mixtank = load(name)
  #  update = %{enable: false}
  #  Changeset.change(mixtank, update) |> Repo.update()
  #end

  defp ensure_inactive(%State{} = state, :nil), do: state
  defp ensure_inactive(%State{} = state, name) when is_binary(name) do
    mixtank = load(name)

    # if the tank is already disabled don't do anything...
    if State.tank_disabled?(state, name) do
      state
    else
      ensure_inactive(state, mixtank)
    end
  end
  defp ensure_inactive(%State{} = state, %Mixtank{} = mixtank) do
    name = mixtank.name

    if not State.tank_disabled?(state, name) do
      Logger.info("mixtank [#{name}] disabled, stopping it.")

      Switch.set_state(mixtank.heat_sw, :false)
      Switch.set_state(mixtank.air_sw, :false)
      Switch.set_state(mixtank.pump_sw, :false)

      state = State.set_heat_disabled(state, name)
      state = State.set_air_disabled(state, name)
      state = State.set_pump_disabled(state, name)
      State.set_control_temp_disabled(state, name)
    else
      state
    end
  end

  defp manage_mixtank(%State{} = state, :nil), do: state
  defp manage_mixtank(%State{} = state, %Mixtank{} = mixtank) do
    case mixtank.enable do
      :true -> follow_ref(state, mixtank)
      :false -> ensure_inactive(state, mixtank)
    end
  end

  defp follow_ref(%State{} = state, %Mixtank{} = mixtank) do
    name = mixtank.name
    val = sensor_value(mixtank.sensor)
    ref_val = sensor_value(mixtank.ref_sensor)

    next_position = calc_next_sw_state(val, ref_val)

    Switch.set_state(mixtank.heat_sw, next_position)
    update = [state_at: Timex.now(), heat_state: next_position]
    mixtank |> Changeset.change(update) |> Repo.update()

    # TODO: transition to new Influx
    #mixtank.heat_sw |> Position.new(next_position) |> Position.post()

    State.set_heat_status(state, name, next_position)
  end

  defp sensor_value(s), do: Sensor.fahrenheit(s)

  # as of 2016-02-26 converted this to be more "Elixir" vs. using "cond"
  defp calc_next_sw_state(val, ref_val)
  when is_float(val) and is_float(ref_val) do
    val = trunc(val) * 1000
    ref_val = trunc(ref_val) * 1000
    calc_next_sw_state(val, ref_val)
  end
  defp calc_next_sw_state(val, ref_val)
  when is_integer(val) and is_integer(ref_val) and val > ref_val, do: :false
  defp calc_next_sw_state(val, ref_val)
  when is_integer(val) and is_integer(ref_val) and val < ref_val, do: :true
  defp calc_next_sw_state(val, ref_val)
  when is_integer(val) and is_integer(ref_val) and val == ref_val, do: :true
  defp calc_next_sw_state(_val, _ref_val), do: :false

  defp update_pump(:nil, _power), do: :nil
  defp update_pump(%Mixtank{} = mixtank, power)
  when is_boolean(power) do

    Switch.set_state(mixtank.pump_sw, power)
    update = [state_at: Timex.now(), pump_state: power]
    mixtank |> Changeset.change(update) |> Repo.update()
  end

  defp update_air(mixtank, power)
  when is_boolean(power) do

    Switch.set_state(mixtank.air_sw, power)
    update = [state_at: Timex.now(), air_state: power]
    mixtank |> Changeset.change(update) |> Repo.update()
  end

  defp start_all(%State{} = state) do
    mixtanks = State.known_mixtanks(state)

    start_mixtank(state, mixtanks)
    send_after(@activate_msg, activate_ms())
  end

  defp start_mixtank(%State{} = state, []), do: state
  defp start_mixtank(%State{} = state, tanks) when is_list(tanks) do
    state |> start_mixtank(hd(tanks)) |> start_mixtank(tl(tanks))
  end

  defp start_mixtank(%State{} = state, :nil), do: state
  defp start_mixtank(%State{} = state, name) when is_binary(name) do
    Mixtank |> Repo.get_by([name: name]) |> start_components(state)
  end

  defp stop_mixtank(%State{} = state, []), do: state
  defp stop_mixtank(%State{} = state, tanks) when is_list(tanks) do
    state |> stop_mixtank(hd(tanks)) |> stop_mixtank(tl(tanks))
  end

  defp stop_mixtank(%State{} = state, :nil), do: state
  defp stop_mixtank(%State{} = state, name) when is_binary(name) do
    mixtank = Repo.get_by(Mixtank, [name: name])
    case mixtank do
      %Mixtank{} = mixtank -> ensure_inactive(state, mixtank)
      _nil_or_unknown -> state
    end
  end

  defp start_components(%Mixtank{enable: :true} = mixtank, %State{} = state) do
    name = mixtank.name
    Logger.info("mixtank [#{name}] enabled, starting up.")

    timer = send_after({@control_temp_msg, name}, 2)
    state = State.set_control_temp_timer(state, name, timer)

    timer = send_after({@pump_on_msg, name}, 2)
    state = State.set_pump_active(state, name, timer)

    timer = send_after({@air_on_msg, name}, 2)
    State.set_air_active(state, name, timer)
  end
  defp start_components(%Mixtank{enable: :false} = mixtank, %State{} = state) do
    name = mixtank.name
    Logger.info("mixtank [#{name}] disabled, will not start.")

    state = State.set_heat_disabled(state, name)
    state = State.set_air_disabled(state, name)
    state = State.set_pump_disabled(state, name)
    State.set_control_temp_disabled(state, name)
  end
  # handle the case where a mixtank isn't passed in
  defp start_components(_anything, %State{} = state), do: state

  def manual_control(code) when is_integer(code) do
    GenServer.cast(Mcp.Mixtank, {@manual_control_msg, code})
  end

  @known_tanks_msg :known_mixtanks

  def known_tanks do
    GenServer.call(Mcp.Mixtank, @known_tanks_msg)
  end

  def handle_call(@known_tanks_msg, _from, %State{} = state) do
    tanks = State.known_mixtanks(state)
    {:reply, tanks, state}
  end

  def handle_call(@shutdown_msg, _from, %State{} = state) do
    # get all known mixtanks and ensure they are inactive
    mixtanks = get_all_mixtank_names()
    state = stop_mixtank(state, mixtanks)

    {:stop, :graceful, state}
  end

  def handle_cast({@manual_control_msg, _code}, %State{} = state) do

    {:noreply, state}
  end

  def handle_info(@init_msg, %State{} = state) do
    state = State.kickstarted(state)

    mixtanks = get_all_mixtank_names()
    state = State.set_known_mixtanks(state, mixtanks)

    start_all(state)

    {:noreply, state}
  end

  def handle_info({@control_temp_msg, name}, %State{} = state)
  when is_binary(name) do

    mixtank = Repo.get_by(Mcp.Mixtank, [name: name])

    # note:  :timer.tc takes a list for the args to pass to the function
    args = [state, mixtank]
    {_elapsed_us, state} = :timer.tc(&manage_mixtank/2, args)

    # elapsed_ms = us_to_ms(elapsed_us)
    timer =
      if mixtank.enable do
        send_after({@control_temp_msg, name}, control_temp_ms())
      else
        :nil
      end

    state = State.set_control_temp_timer(state, name, timer)

    {:noreply, state}
  end

  def handle_info({@pump_on_msg, name}, %State{} =  state)
  when is_binary(name) do
    mixtank = Repo.get_by(Mcp.Mixtank, [name: name])

    state =
      if mixtank != :nil do
        case mixtank.pump_run_ms do
          x when x > 0  -> update_pump(mixtank, :true)
          x when x == 0 -> update_pump(mixtank, :false)
          _rest         -> update_pump(mixtank, :false)
        end

        msg = {@pump_off_msg, name}
        timer = send_after(msg, mixtank.pump_run_ms)
        State.set_pump_active(state, mixtank.name, timer)
      end

    {:noreply, state}
  end

  def handle_info({@pump_off_msg, name}, %State{} = state)
  when is_binary(name) do
    mixtank = Repo.get_by(Mcp.Mixtank, [name: name])

    state =
      if mixtank != :nil do
        case mixtank.pump_idle_ms do
          x when x > 0  -> update_pump(mixtank, :false)
          x when x == 0 -> update_pump(mixtank, :true)
          _rest         -> update_pump(mixtank, :false)
        end

        msg = {@pump_on_msg, name}
        timer = send_after(msg, mixtank.pump_idle_ms)
        State.set_pump_inactive(state, mixtank.name, timer)
      end

    {:noreply, state}
  end

  def handle_info({@air_on_msg, name}, %State{} = state)
  when is_binary(name) do
    mixtank = Repo.get_by(Mcp.Mixtank, [name: name])

    state =
      if mixtank != :nil do
        case mixtank.air_run_ms do
          x when x > 0  -> update_air(mixtank, :true)
          x when x == 0 -> update_air(mixtank, :false)
          _rest         -> update_air(mixtank, :false)
        end

        msg = {@air_off_msg, name}
        timer = send_after(msg, mixtank.air_run_ms)
        State.set_air_active(state, mixtank.name, timer)
      end

    {:noreply, state}
  end

  def handle_info({@air_off_msg, name}, %State{} = state)
  when is_binary(name) do
    mixtank = Repo.get_by(Mcp.Mixtank, [name: name])

    state =
      if mixtank != :nil do
        case mixtank.air_idle_ms do
          x when x > 0  -> update_air(mixtank, :false)
          x when x == 0 -> update_air(mixtank, :true)
          _rest         -> update_air(mixtank, :false)
        end

        msg = {@air_on_msg, name}
        timer = send_after(msg, mixtank.air_idle_ms)
        State.set_air_inactive(state, mixtank.name, timer)
      end

    {:noreply, state}
  end

  def handle_info(@activate_msg, %State{} = state) do
    mixtank_names = get_all_mixtank_names()
    state = State.set_known_mixtanks(state, mixtank_names)

    mixtanks = get_all_mixtanks()
    activate_list =
      for tank <- mixtanks do
        if tank.enable and State.tank_disabled?(state, tank.name) do
          tank.name
        else
          :nil
        end
      end

    state = start_mixtank(state, activate_list)
    send_after(@manage_msg, manage_ms())

    {:noreply, state}
  end

  def handle_info(@manage_msg, %State{} = state) do
    mixtank_names = get_all_mixtank_names()
    state = State.set_known_mixtanks(state, mixtank_names)

    mixtanks = get_all_mixtanks()
    disable_list =
      for tank <- mixtanks do
        if tank.enable == :false and State.tank_enabled?(state, tank.name) do
          tank.name
        else
          :nil
        end
      end

    state = stop_mixtank(state, disable_list)
    send_after(@activate_msg, activate_ms())

    {:noreply, state}
  end

  def code_change(old_vsn, state, _extra) do
    Logger.warn("#{__MODULE__}: code_change from old vsn #{old_vsn}")

    {:ok, state}
  end

  defp config(key)
  when is_atom(key) do
    get_env(:mcp, Mcp.Mixtank) |> Keyword.get(key)
  end

  defp get_all_mixtanks do
    Repo.all(Mixtank)
  end

  defp get_all_mixtank_names do
    query = from m in Mixtank, select: m.name
    Repo.all(query)
  end

  defp send_after(msg, millis) do
    Process.send_after(self(), msg, millis)
  end

  # config helpers
  @control_temp_ms :control_temp_ms
  @activate_ms :activate_ms
  @manage_ms :manage_ms

  defp control_temp_ms, do: get_env(:mcp, Mcp.Mixtank) |> get(@control_temp_ms)
  defp activate_ms, do: get_env(:mcp, Mcp.Mixtank) |> get(@activate_ms)
  defp manage_ms, do: get_env(:mcp, Mcp.Mixtank) |> get(@manage_ms)
end
