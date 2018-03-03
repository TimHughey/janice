defmodule Mcp.Chamber do
  def license,
    do: """
    Master Control Program for Wiss Landing
    Copyright (C) 2016  Tim Hughey (thughey)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>
    """

  @moduledoc """
    Foo Foo Foundation
  """

  require Logger
  use GenServer
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  import Ecto.Query, only: [from: 2]
  import Process, only: [send_after: 3]
  import Application, only: [get_env: 2]
  import Keyword, only: [get: 2]
  alias Ecto.Changeset

  alias Mcp.Chamber
  alias Mcp.Chamber.{ServerState, RunState, Device}

  @vsn 1

  schema "chambers" do
    field(:name, :binary)
    field(:description, :binary)
    field(:enable, :boolean)
    field(:temp_sensor_pri)
    field(:temp_sensor_sec)
    field(:temp_setpt, :integer)
    field(:heat_sw, :binary)
    field(:heat_control_ms, :integer)
    field(:relh_sensor, :binary)
    field(:relh_setpt, :integer)
    field(:relh_sw, :binary)
    field(:relh_control_ms, :integer)
    field(:relh_freq_ms, :integer)
    field(:relh_dur_ms, :integer)
    field(:air_stir_sw, :binary)
    field(:air_stir_temp_diff, :float)
    field(:fresh_air_sw, :binary)
    field(:fresh_air_freq_ms, :integer)
    field(:fresh_air_dur_ms, :integer)
    field(:warm, :boolean, default: true)
    field(:mist, :boolean, default: true)
    field(:fae, :boolean, default: true)
    field(:stir, :boolean, default: true)

    timestamps(usec: true)
  end

  #
  # Database functionality
  #
  def enable(name) when is_binary(name) do
    name |> load_by_name() |> enable(true)
  end

  def disable(name) when is_binary(name) do
    name |> load_by_name() |> enable(false)
  end

  defp enable(nil, _bool), do: :error

  defp enable(%Chamber{} = c, bool) when is_boolean(bool) do
    {res, _} = c |> Changeset.change(enable: bool) |> Repo.update()

    res
  end

  defp all_chambers do
    query = from(c in Chamber, select: c.name)
    Repo.all(query)
  end

  defp load_by_name(name) when is_binary(name) do
    Repo.get_by(Chamber, name: name)
  end

  #
  # Control functions for individual chambers
  #

  defp runstate_init(%ServerState{} = s, []), do: s

  defp runstate_init(%ServerState{} = s, names) when is_list(names) do
    s |> runstate_init(hd(names)) |> runstate_init(tl(names))
  end

  defp runstate_init(%ServerState{} = s, name) when is_binary(name) do
    # load the Chamber config from the database
    c = load_by_name(name)

    # set-up the switches in the RunState
    name
    |> ServerState.run_state(s)
    |> RunState.heater(c.heat_sw)
    |> RunState.air_stir(c.air_stir_sw)
    |> RunState.mist(c.relh_sw)
    |> RunState.fresh_air(c.fresh_air_sw)
    |> ServerState.run_state(s)

    # after completion of this set-up the routine check message
    # will handle starting the Chamber
  end

  @warm_msg :warm_msg
  @mist_msg :mist_msg
  # @mist_end_msg :mist_end_msg
  @fresh_air_msg :fresh_air_msg
  @fresh_air_end_msg :fresh_air_end_msg
  @stir_msg :stir_msg
  defp control_chambers(%ServerState{} = s, []), do: s

  defp control_chambers(%ServerState{} = s, names)
       when is_list(names) do
    s |> control_chambers(hd(names)) |> control_chambers(tl(names))
  end

  defp control_chambers(%ServerState{} = s, n) when is_binary(n) do
    c = load_by_name(n)
    control_chambers(s, c)
  end

  defp control_chambers(%ServerState{} = s, %Chamber{enable: true} = c) do
    rs = ServerState.run_state(s, c.name)

    if RunState.disabled?(rs) do
      control_chamber(s, rs, :start)
    else
      s
    end
  end

  defp control_chambers(%ServerState{} = s, %Chamber{enable: false} = c) do
    rs = ServerState.run_state(s, c.name)

    if RunState.enabled?(rs) do
      control_chamber(s, rs, :stop)
    else
      s
    end
  end

  # if the chamber's RunState is disabled then start it up

  defp control_chamber(%ServerState{} = s, %RunState{} = rs, :start) do
    name = RunState.name(rs)

    Logger.info(fn -> "chamber [#{name}] enabled, starting." end)

    send_after(self(), {@warm_msg, name}, :rand.uniform(50))
    send_after(self(), {@mist_msg, name}, :rand.uniform(50))
    send_after(self(), {@fresh_air_msg, name}, :rand.uniform(50))
    send_after(self(), {@stir_msg, name}, :rand.uniform(50))

    rs |> RunState.idle_all() |> ServerState.run_state(s)
  end

  # if the chamber's RunState is enabled then shut it down
  defp control_chamber(%ServerState{} = s, %RunState{} = rs, :stop) do
    name = RunState.name(rs)

    Logger.info(fn -> "chamber [#{name}] disabled, stopping." end)
    rs |> RunState.disable_all() |> ServerState.run_state(s)
  end

  defp warm(%ServerState{} = s, n) when is_binary(n) do
    c = load_by_name(n)
    rs = ServerState.run_state(s, n)

    t = send_after(self(), {@warm_msg, c.name}, c.heat_control_ms)
    warm(s, rs, RunState.heater_running?(rs), need_warm?(c), t)
  end

  defp warm(%ServerState{} = s, %RunState{} = rs, actual, need, t)
       when is_boolean(need) and is_boolean(actual) and is_reference(t) do
    rs |> RunState.heater(need, t) |> ServerState.run_state(s)
  end

  # check Chamber config to determine if *anything* should be done
  defp need_warm?(%Chamber{enable: false}), do: false
  defp need_warm?(%Chamber{warm: false}), do: false

  defp need_warm?(%Chamber{warm: true} = c) do
    pri = Sensor.fahrenheit(c.temp_sensor_pri)
    sec = Sensor.fahrenheit(c.temp_sensor_sec)
    need_warm?(c, pri, sec)
  end

  # use average of primary and secondary temperatures if they both make sense
  defp need_warm?(%Chamber{} = c, pri, sec)
       when is_float(pri) and pri >= 40.0 and is_float(sec) and sec >= 40.0 do
    val = (pri + sec) / 2

    need_warm?(c, val)
  end

  # if the primary temperature is not available then only use the
  # secondary temperature
  defp need_warm?(%Chamber{} = c, pri, sec)
       when (is_nil(pri) or (is_float(pri) and pri < 40.0)) and is_float(sec) do
    s1 = inspect(pri)
    msg = "Chamber: [#{c.name}] primary temp=#{s1}, using secondary temp"
    Logger.warn(msg)

    need_warm?(c, sec)
  end

  defp need_warm?(%Chamber{} = c, pri, sec)
       when is_nil(pri) or is_nil(sec) do
    s1 = inspect(pri)
    s2 = inspect(sec)
    msg = "Chamber [#{c.name}] detected temp sensor " <> "pri=#{s1} sec=#{s2}"
    Logger.warn(msg)

    false
  end

  # catch all if nothing above matches
  defp need_warm?(%Chamber{}, _pri, _sec), do: false

  defp need_warm?(%Chamber{} = c, val) when is_float(val) do
    # for now use integers for comparison
    val = Float.round(val, 0)

    setpt = c.temp_setpt

    case val do
      x when x > setpt -> false
      x when x <= setpt -> true
    end
  end

  defp mist(%ServerState{} = s, n) when is_binary(n) do
    c = load_by_name(n)
    rs = ServerState.run_state(s, n)

    # always schedule the next mist check
    t = send_after(self(), {@mist_msg, c.name}, c.relh_control_ms)

    mist(s, rs, RunState.mist_running?(rs), need_mist?(c, rs), t)
  end

  # if mist is running and we've determined no mist is needed then
  # shutoff devices.
  defp mist(%ServerState{} = s, %RunState{} = rs, true = _mist_running, false = _need_mist, t)
       when is_reference(t) do
    rs
    |> RunState.mist(false, t)
    |> RunState.fresh_air(false, nil)
    |> ServerState.run_state(s)
  end

  # if mist is not running and we've determined no mist is needed then
  # only update the mist timer and don't change the fresh air device.
  # this is essential to avoid a competition between mist and fresh air cycle
  defp mist(%ServerState{} = s, %RunState{} = rs, false = _mist_running, false = _need_mist, t)
       when is_reference(t) or t == nil do
    rs |> RunState.mist(false, t) |> ServerState.run_state(s)
  end

  defp mist(%ServerState{} = s, %RunState{} = rs, _mist_running, need_mist, t)
       when is_reference(t) do
    rs
    |> RunState.mist(need_mist, t)
    |> RunState.fresh_air(need_mist, nil)
    |> ServerState.run_state(s)
  end

  # check Chamber config to determine if mist should be controlled
  defp need_mist?(%Chamber{enable: false}, %RunState{}), do: false
  defp need_mist?(%Chamber{enable: true, mist: false}, %RunState{}), do: false

  # determine if mist is needed based on measured relative humidity
  defp need_mist?(%Chamber{enable: true, mist: true} = c, %RunState{} = rs) do
    need_mist?(c, rs, :relhum) or need_mist?(c, rs, :duration)
  end

  defp need_mist?(%Chamber{}, %RunState{}, nil), do: false

  defp need_mist?(%Chamber{} = c, %RunState{}, :relhum) do
    rh = Sensor.relhum(c.relh_sensor)
    max = c.relh_setpt
    min = c.relh_setpt

    # the check for < 10 is a workaround for unreliable humidity sensor
    # that sometimes reports zero (0)
    case Float.round(rh, 0) do
      x when x >= max -> false
      x when x <= max and x > min and x > 10 -> true
      x when x <= min and x < min and x > 10 -> true
      x when x <= 10 -> false
    end
  end

  defp need_mist?(%Chamber{mist: true} = c, %RunState{} = rs, :duration) do
    case RunState.mist_running?(rs) do
      true -> not RunState.mist_state_elapsed?(rs, c.relh_dur_ms)
      false -> RunState.mist_state_elapsed?(rs, c.relh_freq_ms)
    end
  end

  # these are a series of chained functions to decide if
  # fresh air should be introduced to the chamber

  # this is the primary entry point to the fresh air decision
  # that takes the server state and name of chamber that needs a decision
  defp fresh_air(%ServerState{} = s, n) when is_binary(n) do
    c = load_by_name(n)
    rs = ServerState.run_state(s, c.name)

    fresh_air(s, c, need_fresh_air?(c, rs))
  end

  # ok, the decision to add fresh air is yes so turn on the device
  defp fresh_air(%ServerState{} = s, %Chamber{} = c, true) do
    rs = ServerState.run_state(s, c.name)

    msg = {@fresh_air_end_msg, rs.name}
    t = send_after(self(), msg, c.fresh_air_dur_ms)

    rs |> RunState.fresh_air(true, t) |> ServerState.run_state(s)
  end

  # fresh_air(ServerStatus, Chamber, no_fresh_air_needed)
  # 1 of 2:
  # decision is to not add fresh air.  in this case the only action is
  # sending self a fresh_air_msg to continue checking
  defp fresh_air(%ServerState{} = s, %Chamber{fae: true}, false), do: s

  # fresh_air(ServerStatus, Chamber, no_fresh_air_needed)
  # 2 of 2:
  # decision is to not add fresh air and fae is disabled.  in thie case
  # truly do nothing since the next routine_check / control_chambers will
  # kickoff the fresh_air_msg when the chamber is enabled
  defp fresh_air(%ServerState{} = s, %Chamber{fae: false}, false), do: s

  # check Chamber config to determine if fresh air should be controlled
  defp need_fresh_air?(%Chamber{enable: false}, %RunState{}), do: false

  defp need_fresh_air?(%Chamber{fae: true} = c, %RunState{} = rs) do
    RunState.fresh_air_idle?(rs, c.fresh_air_freq_ms)
  end

  defp need_fresh_air?(%Chamber{fae: false}, %RunState{}), do: false

  # here's the other side of the fresh air action that decides if
  # fresh air should be stopped noting that fresh air is part of
  # the mist cycle
  defp fresh_air_end(%ServerState{} = s, n) when is_binary(n) do
    rs = ServerState.run_state(s, n)

    fresh_air_end(s, rs, RunState.mist_running?(rs))
  end

  # if mist is active then fresh air must remain active
  defp fresh_air_end(%ServerState{} = s, %RunState{}, true), do: s
  # if mist is NOT active then fresh air can be stopped
  defp fresh_air_end(%ServerState{} = s, %RunState{} = rs, false) do
    rs |> RunState.fresh_air(false, nil) |> ServerState.run_state(s)
  end

  defp stir(%ServerState{} = s, n) when is_binary(n) do
    c = load_by_name(n)
    rs = ServerState.run_state(s, c.name)

    stir(s, c, need_stir?(c), RunState.air_stir_running?(rs))
  end

  # here we compare the desired air stir (need) to the current (actual) and
  # depending on which function matches either change air stir to need or
  # do nothing
  # goal here is to avoid sending switch messages if no change is needed
  defp stir(%ServerState{} = s, %Chamber{} = c, need, actual)
       when is_boolean(need) and is_boolean(actual) and need != actual do
    rs = ServerState.run_state(s, c.name)
    rs |> RunState.air_stir(need, nil) |> ServerState.run_state(s)
  end

  defp stir(%ServerState{} = s, %Chamber{}, need, actual)
       when is_boolean(need) and is_boolean(actual) and need == actual,
       do: s

  # use Chamber config to determine if air stir is desired
  defp need_stir?(%Chamber{enable: false}), do: false
  defp need_stir?(%Chamber{stir: false}), do: false

  # if Chamber has air stir enabled then use the primary and secondary
  # to determine if air stir should commence
  defp need_stir?(%Chamber{stir: true} = c) do
    pri = Sensor.fahrenheit(c.temp_sensor_pri)
    sec = Sensor.fahrenheit(c.temp_sensor_sec)
    need_stir?(c.air_stir_temp_diff, abs(pri - sec))
  end

  # compare the set difference to the actual delta to decide if
  # stir is needed
  defp need_stir?(set_diff, actual)
       when is_number(set_diff) and is_number(actual) and actual >= set_diff,
       do: true

  defp need_stir?(set_diff, actual)
       when is_number(set_diff) and is_number(actual) and actual < set_diff,
       do: false

  @routine_check_msg {:routine_check_msg}
  defp schedule_routine_check do
    routine_check_ms = get_env(:mcp, Mcp.Chamber) |> get(:routine_check_ms)
    send_after(self(), @routine_check_msg, routine_check_ms)
  end

  defp format_status(nil), do: ["unknown chamber"]

  defp format_status(%RunState{} = rs) do
    he = RunState.heater(rs)
    hes = String.pad_trailing(inspect(Device.running?(he)), 8)
    hets = Timex.format!(Device.ts(he), "{RFC822z}")
    mi = RunState.mist(rs)
    mis = String.pad_trailing(inspect(Device.running?(mi)), 8)
    mits = Timex.format!(Device.ts(mi), "{RFC822z}")
    fa = RunState.fresh_air(rs)
    fas = String.pad_trailing(inspect(Device.running?(fa)), 8)
    fats = Timex.format!(Device.ts(fa), "{RFC822z}")
    as = RunState.air_stir(rs)
    ass = String.pad_trailing(inspect(Device.running?(as)), 8)
    asts = Timex.format!(Device.ts(as), "{RFC822z}")

    a = ""
    b = "Chamber: #{rs.name}\n"
    c = "  device    running?  timestamp"
    d = "  --------  --------  -------------------------"
    e = "  heater    #{hes}  #{hets}"
    f = "  mist      #{mis}  #{mits}"
    g = "  fae       #{fas}  #{fats}"
    h = "  air stir  #{ass}  #{asts}"
    i = ""

    [a, b, c, d, e, f, g, h, i]
  end

  #
  # GenServer start, init and stop
  #

  def start_link(args) do
    GenServer.start_link(Mcp.Chamber, args, name: Mcp.Chamber)
  end

  @start_msg {:start}
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(s) when is_map(s) do
    state =
      %ServerState{}
      |> ServerState.kickstart()
      |> ServerState.known_chambers(all_chambers())
      |> Kernel.struct(s)

    autostart_ms = get_env(:mcp, Mcp.Chamber) |> get(:autostart_wait_ms)

    case Map.get(s, :autostart, false) do
      true ->
        if autostart_ms > 0 do
          send_after(self(), @start_msg, autostart_ms)
        end

      false ->
        nil
    end

    Logger.info("init()")

    {:ok, state}
  end

  def stop do
    GenServer.stop(Mcp.Chamber)
  end

  @disabled_list_msg {:disabled_list_msg}
  def disabled_list do
    GenServer.call(Mcp.Chamber, @disabled_list_msg)
  end

  @known_msg {:known_list_msg}
  def known, do: GenServer.call(Mcp.Chamber, @known_msg)

  @chamber_status_msg :chamber_status_msg
  def status(name, :print) when is_binary(name) do
    name |> status() |> Enum.join("\n") |> IO.puts()
  end

  def status(name) when is_binary(name) do
    GenServer.call(Mcp.Chamber, {@chamber_status_msg, name})
  end

  #
  # GenServer callbacks
  #

  def handle_info(@start_msg, %ServerState{} = s) do
    s = runstate_init(s, ServerState.known_chambers(s))

    # start the routine update functionality which is handle bringing
    # online enabled chambers
    schedule_routine_check()

    {:noreply, s}
  end

  def handle_info(@routine_check_msg, %ServerState{} = s) do
    names = all_chambers()

    s =
      s
      |> ServerState.record_routine_check()
      |> ServerState.known_chambers(names)
      |> control_chambers(names)

    schedule_routine_check()
    {:noreply, s}
  end

  def handle_info({@warm_msg, n}, %ServerState{} = s)
      when is_binary(n) do
    s = warm(s, n)

    {:noreply, s}
  end

  def handle_info({@mist_msg, n}, %ServerState{} = s)
      when is_binary(n) do
    s = mist(s, n)

    {:noreply, s}
  end

  # def handle_info({@mist_end_msg, n}, %ServerState{} = s)
  # when is_binary(n) do
  #  s = mist_end(s, n)
  #
  #  {:noreply, s}
  # end

  def handle_info({@fresh_air_msg, n}, %ServerState{} = s)
      when is_binary(n) do
    s = fresh_air(s, n)

    # always schedule the next fresh air msg for this chamber name
    msg = {@fresh_air_msg, n}
    routine_check_ms = get_env(:mcp, Mcp.Chamber) |> get(:routine_check_ms)
    send_after(self(), msg, routine_check_ms)

    {:noreply, s}
  end

  def handle_info({@fresh_air_end_msg, n}, %ServerState{} = s)
      when is_binary(n) do
    s = fresh_air_end(s, n)

    {:noreply, s}
  end

  def handle_info({@stir_msg, n}, %ServerState{} = s)
      when is_binary(n) do
    s = stir(s, n)

    msg = {@stir_msg, n}
    routine_check_ms = get_env(:mcp, Mcp.Chamber) |> get(:routine_check_ms)
    send_after(self(), msg, routine_check_ms)

    {:noreply, s}
  end

  def handle_call(@disabled_list_msg, _from, s) do
    {:reply, [], s}
  end

  def handle_call(@known_msg, _from, s) do
    kc = s.known_chambers.names

    {:reply, kc, s}
  end

  def handle_call({@chamber_status_msg, name}, _from, %ServerState{} = s) do
    msg = s.chambers |> Map.get(name) |> format_status()

    {:reply, msg, s}
  end

  def code_change(old_vsn, s, _extra) do
    Logger.warn(fn -> "#{__MODULE__}: code_change from old vsn #{old_vsn}" end)
    {:ok, s}
  end
end
