defmodule Mcp.I2cSensor do
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
    This module implements I2cSensor as a GenServer
  """

  require Logger
  use Timex
  use Mcp.GenServer
  use Bitwise

  alias ElixirALE.I2C
  alias Mcp.{I2cSensor, I2cSensor.ServerState, Reading, Switch}

  # increment this attribute whenever State struct changes and implemenation
  # new state upgrade actions in code_change
  @vsn 3

  @temperature "temperature"
  @humidity "humidity"

  # definition of messages that can be sent to this server
  @available_msg :available?
  @sensor_list_msg :get_sensor_list
  @sensor_and_reading_list_msg :get_sensor_and_reading_list
  @get_sensor_reading_msg :get_sensor_reading
  @temp_cycle_start_msg :temp_convert_start
  @temp_available_msg :temp_available?
  @temp_cycle_serial_num_msg :temp_serial_num

  # @true_string "1"
  # @false_string "0"

  def call_timeout_ms, do: config(:call_timeout_ms)
  def temp_refresh_ms, do: config(:temp_refresh_ms)
  def temp_cycle_wait_ms, do: sht_wait_ms() + hih_wait_ms()
  def kickstart_wait_ms, do: config(:kickstart_wait_ms)
  def i2c_mode, do: config(:mode)
  def i2c_device, do: config(:i2c_device)
  def sht_addr, do: config(:sht).address
  def sht_name, do: config(:sht).name
  def sht_wait_ms, do: config(:sht).wait_ms
  def hih_addr, do: config(:hih).address
  def hih_name, do: config(:hih).name
  def hih_wait_ms, do: config(:hih).wait_ms
  def am2315_addr, do: config(:am2315).address
  def am2315_name, do: config(:am2315).name
  def am2315_wait_ms, do: config(:am2315).wait_ms
  def am2315_pwr_sw, do: config(:am2315).pwr_sw
  def am2315_pwr_wait_ms, do: config(:am2315).pwr_wait_ms

  @doc """
  Traditional implemenation of start_link
  """
  def start_link(_args) do
    s = ServerState.set_available(%ServerState{})
    start_link(Mcp.I2cSensor, config(:name), s)
  end

  def init(s) do

    sensors = [
        %{name: sht_name(), device: :sht},
        %{name: hih_name(), device: :hih},
        %{name: am2315_name(), device: :am2315}]

    s = s |>
          ServerState.set_sensors(sensors) |>
          ServerState.kickstarted() |>
          start_i2c()

    Process.send_after(self(), @temp_cycle_start_msg, kickstart_wait_ms())

    {:ok, s}
  end

  defp start_i2c(%ServerState{} = s) do
      s |>
        ServerState.confirm_i2c_dev() |>
        start_i2c(ServerState.i2c_dev_exists?(s))
  end

  # simulate the i2c devices
  defp start_i2c(%ServerState{} = s, :simulate) do
    ServerState.set_pids(s, :sim, :sim, :sim)
  end

  # use the real i2c devices
  defp start_i2c(%ServerState{} = s, :actual), do: start_i2c(s)

  defp start_i2c(%ServerState{} = s, :true) do

    Switch.position(am2315_pwr_sw(), :true)

    {:ok, sht_pid} =
      case ServerState.get_sht_pid(s) do
        :nil  -> I2C.start_link(i2c_device(), sht_addr())
        _any  -> {:ok, ServerState.get_sht_pid(s)}
      end

    {:ok, hih_pid} =
      case ServerState.get_hih_pid(s) do
        :nil  -> I2C.start_link(i2c_device(), hih_addr())
        _any  -> {:ok, ServerState.get_hih_pid(s)}
      end

    {:ok, am2315_pid} =
      case ServerState.get_am2315_pid(s) do
        :nil  -> I2C.start_link(i2c_device(), am2315_addr())
        _any  -> {:ok, ServerState.get_am2315_pid(s)}
      end

    ServerState.set_pids(s, sht_pid, hih_pid, am2315_pid)
  end

  defp start_i2c(%ServerState{} = s, :false) do
    s |> ServerState.get_sht_pid() |> I2C.release()
    s |> ServerState.get_hih_pid() |> I2C.release()
    s |> ServerState.get_am2315_pid() |> I2C.release()
    s |> ServerState.clear_pids()
  end

  def available? do
    call({@available_msg})
  end

  def temp_cycle_done? do
    call(@temp_available_msg)
  end

  def temp_cycle_serial_num do
    call(@temp_cycle_serial_num_msg)
  end

  def recommended_next_temp_ms do
    temp_refresh_ms() + temp_cycle_wait_ms()
  end

  def known_sensor?(name) when is_binary(name) do
    Regex.match?(~r/i2c/, name)
  end

  def start_temp do
    Process.send_after(self(), @temp_cycle_start_msg, kickstart_wait_ms())
  end

  def read_sensor(name) when is_binary(name) do
    call({@get_sensor_reading_msg, name})
  end

  def sensor_list(pattern \\ :nil) do
    case GenServer.whereis(server_name()) do
      :nil -> no_server("I2cSensor.sensor_list")
      _ -> call({@sensor_list_msg, pattern})
    end
  end

  def sensor_and_reading_list(pattern) do
    call({@sensor_and_reading_list_msg, pattern})
  end

  defp call(msg) do
    GenServer.call(server_name(), msg, call_timeout_ms())
  end

  defp async_temp_convert(%ServerState{} = s) do
    async_temp_convert(s, ServerState.temp_cycle_idle?(s))
  end

  defp async_temp_convert(%ServerState{} = s, :true) do

    pids = %{sht: ServerState.get_sht_pid(s),
             hih: ServerState.get_hih_pid(s),
             am2315: ServerState.get_am2315_pid(s)}

    task = Task.Supervisor.async(I2cSensor.Task.Supervisor,
                                  I2cSensor.Task,
                                  :async_temp_convert, [pids])

    str = inspect(task)
    Logger.debug fn -> "I2cSensor: async temp convert via #{str}" end

    s |>
      ServerState.put_temp_cycle_task(task) |>
      ServerState.temp_cycle_start()
  end

  defp async_temp_convert(%ServerState{} = s, :false) do
    Logger.warn("I2cSensor: temp convert already active!")
    s
  end

  defp async_reset_am2315 do
    Task.Supervisor.async(Mcp.I2cSensor.Task.Supervisor,
                            Mcp.I2cSensor.Task,
                            :async_reset_am2315, [])
  end

  #
  # HANDLE CALL / HANDLE CAST
  #
  def handle_call({:debug}, _from, s) do
    Process.send_after(self(), @temp_cycle_start_msg, kickstart_wait_ms())
    {:reply, [], s}
  end

  def handle_call({@available_msg}, _from, s) do
    s = ServerState.set_available(s)
    {:reply, ServerState.available?(s), s}
  end

  def handle_call(@temp_available_msg, _from, s) do
    {:reply, ServerState.temp_cycle_recent?(s), s}
  end

  def handle_call(@temp_cycle_serial_num_msg, _from, s) do
    {:reply, ServerState.temp_cycle_serial(s), s}
  end

  def handle_call({@get_sensor_reading_msg, name}, _from, s) do
    result = do_read_sensor(s, name)

    {:reply, result, s}
  end

  def handle_call({@sensor_list_msg, _regex}, _from, s) do
    sensors = ServerState.get_sensors(s)
    {:reply, sensors, s}
  end

  def handle_call({@sensor_and_reading_list_msg, _regex}, _from, s) do
    sensors = ServerState.get_sensors(s)

    list =
      for sensor <- sensors do
        for reading <- available_readings(sensor) do
          %{name: sensor, reading: reading}
        end
      end |> List.flatten

    {:reply, list, s}
  end

  def handle_info(@temp_cycle_start_msg, s) do
    s = start_i2c(s, i2c_mode())
    s = async_temp_convert(s)

    {:noreply, s}
  end

  def handle_info({r, {:ok, :temp_convert_done, readings}}, s)
  when is_map(readings) do
    str = inspect(r)
    Logger.debug fn -> "I2cSensor: temp_convert complete: #{str}" end

    s = ServerState.set_sht_reading(s, readings.sht)
    s = ServerState.set_hih_reading(s, readings.hih)
    s = ServerState.set_am2315_reading(s, readings.am2315)

    if Reading.invalid?(readings.am2315.temperature), do: async_reset_am2315()

    s = ServerState.clear_temp_cycle_task(s)
    s = ServerState.temp_cycle_end(s)
    Process.send_after(self(), @temp_cycle_start_msg, temp_refresh_ms())

    {:noreply, s}
  end

  @am2315_reset_done_msg {:ok, :am2315_reset_done, []}
  def handle_info({_r, @am2315_reset_done_msg}, %ServerState{} = s) do

    {:noreply, s}
  end

  def handle_info({:DOWN, r, :process, p, reason}, s)
  when is_reference(r) and is_pid(p)  do

    ref = inspect(r)
    pid = inspect(p)

    msg = "I2cSensorTask: #{ref} #{pid} exited [#{reason}]"

    case reason do
      :normal  -> Logger.debug(msg)
      _other   -> Logger.warn(msg)
    end

    {:noreply, s}
  end

  def code_change(old_vsn, s, _extra) do
    Logger.warn fn -> "I2cSensor: code_change from old vsn #{old_vsn}" end

    {:ok, s}
  end

  defp available_readings(name) when is_binary(name) do
    [@temperature, @humidity]
  end

  defp do_read_sensor(%ServerState{} = s, name) when is_binary(name) do
    for reading <- available_readings(name) do
      device = ServerState.get_sensor_device(s, name)

      r = ServerState.get_reading(s, device)
      Map.get(r, reading)
    end
  end

  defp no_server(msg) do
    Logger.warn fn -> "GenServer.whereis failed for #{msg}" end
    []
  end

end
