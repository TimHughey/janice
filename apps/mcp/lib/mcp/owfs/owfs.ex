defmodule Mcp.Owfs do
  def license, do: """
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
    This module implements Owfs as a GenServer
  """

  use Timex
  use Mcp.GenServer

  require Logger

  alias Mcp.Owfs.{ServerState, Sensor}

  @latch "latch.B"

  # definition of messages that can be sent to this server
  @available_msg :available?
  @num_buses_msg :num_buses
  @sensor_list_msg :get_sensor_list
  @sensor_and_reading_list_msg :get_sensor_and_reading_list
  @get_sensor_reading_msg :get_sensor_reading
  @get_switch_position_msg :get_switch_position
  @set_switch_position_msg :set_switch_position
  @temp_cycle_start_msg :temp_convert_start
  @temp_available_msg :temp_available?
  @temp_cycle_serial_num_msg :temp_serial_num
  @get_latch_msg :get_latch_msg
  @true_string "1"
  @false_string "0"

  def timeout_ms, do: config(:call_timeout_ms)
  def temp_refresh_ms, do: config(:temp_refresh_ms)
  def kickstart_wait_ms, do: config(:kickstart_wait_ms)
  def write_max_retries, do: config(:write_max_retries)
  def write_retry_ms, do: config(:write_retry_ms)
  def sensor_regex do
    {:ok, regex} = Regex.compile(config(:sensor_regex))
    regex
  end

  @doc """
  Traditional implemenation of start_link
  """
  def start_link(_args) do
    state = ServerState.set_available(%ServerState{})
    start_link(Mcp.Owfs, config(:name), state)
  end

  def init(state) do
    state = ServerState.kickstarted(state)

    Process.send_after(self(), @temp_cycle_start_msg, kickstart_wait_ms())

    {:ok, state}
  end

  def available? do
    GenServer.call(server_name(), {@available_msg}, timeout_ms())
  end

  def num_buses do
    GenServer.call(server_name(), @num_buses_msg, timeout_ms())
  end

  def temp_cycle_done? do
    GenServer.call(server_name(), @temp_available_msg, timeout_ms())
  end

  def temp_cycle_serial_num do
    GenServer.call(server_name(), @temp_cycle_serial_num_msg, timeout_ms())
  end

  def ttl, do: temp_refresh_ms()
  def recommended_next_temp_ms, do: ttl()
  def volatile_timeout_ms, do: ttl()
  def volatile_timeout, do: trunc(ttl() / 1000)

  def read_sensor(name) when is_binary(name) do
    call({@get_sensor_reading_msg, name})
  end

  def read_sensor(name, reading)
  when is_binary(name) and is_binary(reading) do
    call({@get_sensor_reading_msg, name, reading})
  end

  def sensors do
    call({@sensor_list_msg})
  end

  def sensor_and_reading_list do
    call({@sensor_and_reading_list_msg})
  end

  def get_switch_position(group, pio) do
    call({@get_switch_position_msg, group, pio})
  end

  def switch_set(group, pio, state)
  when is_atom(state) do
    call({@set_switch_position_msg, group, pio, state})
  end

  def switch_set(group, pio, state, :cast)
  when is_atom(state) do
    cast({@set_switch_position_msg, group, pio, state})
  end

  def get_latch(group, clear \\ :false)
  when is_binary(group) and is_boolean(clear) do
    call({@get_latch_msg, group, clear})
  end

  defp call(msg) do
    GenServer.call(server_name(), msg, timeout_ms())
  end

  defp cast(msg) do
    GenServer.cast(server_name(), msg)
  end

  defp async_temp_convert(%ServerState{} = s) do
    async_temp_convert(s, ServerState.temp_cycle_idle?(s))
  end

  defp async_temp_convert(%ServerState{} = s, :true) do
    task = Task.Supervisor.async(Mcp.Owfs.Task.Supervisor, Mcp.Owfs.Task,
                              :async_temp_convert, [])

    str = inspect(task)
    Logger.debug fn -> "Owfs: async temp convert via #{str}" end

    s |>
      ServerState.put_temp_cycle_task(task) |>
      ServerState.temp_cycle_start()
  end

  defp async_temp_convert(%ServerState{} = s, :false) do
    Logger.warn("Owfs: temp convert already active!")
    s
  end

  defp position_file(group, pio) do
    Path.join([config(:path), group, pio])
  end

  defp do_read_switch(group, pio)
  when is_binary(group) and is_binary(pio) do
    read_state(position_file(group, pio))
  end

  defp do_read_latch(group) when is_binary(group) do
    read_state(position_file(group, @latch))
  end

  defp do_clear_latch(_group, :false), do: :nil
  defp do_clear_latch(group, :true)
  when is_binary(group) do
    clear_latch(group)
  end

  defp binary_to_bool(@false_string), do: :false
  defp binary_to_bool(@true_string), do: :true
  defp bool_to_binary(v) do
    case v do
      :true  -> @true_string
      "1"    -> @true_string
      :false -> @false_string
      "0"    -> @false_string
    end
  end

  defp read_state(file_path) do
    with {:ok, binary} <- File.read(file_path),
      do: {:ok, binary_to_bool(binary)}
  end

  # here is where the real work is done with error check + retry
  def do_set_switch(group, pio, position)
  when is_binary(group) and is_binary(pio) do
    case write_switch_position(group, pio, position) do
      :ok              -> :ok
      {:error, reason} -> retry_set_switch(group, pio, position,
                              reason, write_max_retries())
    end
  end

  defp write_switch_position(group, pio, position)
  when is_binary(group) and is_binary(pio) do
    File.write(position_file(group, pio), bool_to_binary(position))
  end

  defp retry_set_switch(group, pio, _position, reason, retries)
  when is_binary(group) and is_binary(pio) and retries <= 0 do
    msg = "switch: #{group}:#{pio}"
    Logger.warn fn -> "#{msg} exceeded write retry count reason:#{msg}" end
    {:error, reason}
  end

  defp retry_set_switch(group, pio, position, reason, retries)
  when is_binary(group) and is_binary(pio) do
    :timer.sleep(write_retry_ms())

    msg = "switch: #{group}:#{pio}"
    count = write_max_retries() - retries + 1
    Logger.warn fn -> "#{msg} write retry # #{count} reason:#{reason}" end

    case write_switch_position(group, pio, position) do
      :ok              -> :ok
      {:error, reason} -> retry_set_switch(group, pio, position,
                             reason, retries - 1)
    end
  end

  defp clear_latch(group)
  when is_binary(group) do
    File.write(position_file(group, @latch), bool_to_binary(:false))
  end

  #
  # HANDLE CALL / HANDLE CAST
  #
  def handle_call({@available_msg}, _from, state) do
    state = ServerState.set_available(state)
    {:reply, ServerState.available?(state), state}
  end

  def handle_call(@num_buses_msg, _from, state) do
    {:reply, ServerState.num_buses(state), state}
  end

  def handle_call(@temp_available_msg, _from, state) do
    {:reply, ServerState.temp_cycle_recent?(state), state}
  end

  def handle_call(@temp_cycle_serial_num_msg, _from, state) do
    {:reply, ServerState.temp_cycle_serial(state), state}
  end

  def handle_call({@get_sensor_reading_msg, name}, _from, state) do
    {_elapsed_us, result} = :timer.tc(&Sensor.reading/1, [name])

    {:reply, result, state}
  end

  def handle_call({@get_sensor_reading_msg, name, reading}, _from, state) do
    r = Sensor.reading(name, reading)

    {:reply, r, state}
  end

  def handle_call({@sensor_list_msg}, _from, s) do
    {:reply, Sensor.all(), s}
  end

  def handle_call({@sensor_and_reading_list_msg}, _from, state) do

    list =
      for sensor <- Sensor.all() do
        for reading <- Sensor.available_readings(sensor) do
          %{name: sensor, reading: reading}
        end
      end |> List.flatten

    {:reply, list, state}
  end

  def handle_call({@get_switch_position_msg, group, pio}, _from, state) do
    {:reply, do_read_switch(group, pio), state}
  end

  def handle_call({@set_switch_position_msg, group, pio, val}, _from, s) do
    do_set_switch(group, pio, val)

    {:reply, :ok, s}
  end

  def handle_call({@get_latch_msg, group, clear}, _from, %ServerState{} = state)
  when is_boolean(clear) do
    res = do_read_latch(group)
    do_clear_latch(group, clear)

    {:reply, res, state}
  end

  def handle_cast({@set_switch_position_msg, group, pio, val}, s) do
    do_set_switch(group, pio, val)

    {:noreply, s}
  end

  def handle_info(@temp_cycle_start_msg, %ServerState{} = s) do
    s = async_temp_convert(s)

    {:noreply, s}
  end

  def handle_info({r, {:ok, :temp_convert_done, count}}, s) do
    ref = inspect(r)
    Logger.debug fn -> "OwfsTask: temp_convert complete: " <>
                        "#{ref}, buses: #{count}" end

    s = ServerState.temp_cycle_end(s)
    s = ServerState.set_num_buses(s, count)
    s = ServerState.clear_temp_cycle_task(s)

    Process.send_after(self(), @temp_cycle_start_msg, temp_refresh_ms())

    {:noreply, s}
  end

  def handle_info({:DOWN, r, :process, p, reason}, s)
  when is_reference(r) and is_pid(p)  do

    ref = inspect(r)
    pid = inspect(p)

    case reason do
      :normal  -> Logger.debug fn -> "OwfsTask: " <>
                                      "#{ref} #{pid} exited [#{reason}]" end
      _other   -> Logger.warn fn -> "OwfsTask: " <>
                                      "#{ref} #{pid} exited [#{reason}])" end
    end

    {:noreply, s}
  end

end
