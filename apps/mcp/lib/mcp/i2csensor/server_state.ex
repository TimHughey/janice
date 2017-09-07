defmodule Mcp.I2cSensor.ServerState do
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
  @moduledoc :false

  require Logger
  use Timex

  alias Mcp.{I2cSensor.ServerState, I2cSensor, Util, Reading}

  @unset :nil
  @never :never
  @complete :complete
  @in_progress :in_progres
  @ts :ts
  @kickstarted :kickstarted
  @i2c_dev_exists :i2c_dev_exists
  @temp_cycle_task :temp_cycle_task
  @available :available
  @status :status
  @pids :pids
  @sht_pid :sht_pid
  @hih_pid :hih_pid
  @am2315_pid :am2315_pid
  @sensors :sensors
  @readings :readings
  @sht :sht
  @hih :hih
  @am2315 :am2315

  defstruct kickstarted: %{@ts =>Timex.zero(), @status => @never},
    i2c_dev_exists: %{@ts => Timex.zero(), @status => :false},
    available: %{@ts => Timex.zero(), @status => @never},
    temp_cycle: %{@ts => Timex.zero(), @status => @never},
    pids: %{@sht_pid => @unset, @hih_pid => @unset, @am2315_pid => @unset},
    temp_cycle_task: %Task{},
    sensors: [],
    readings: %{@sht => %{temp: %Reading{}, rh: %Reading{}},
                @hih => %{temp: %Reading{}, rh: %Reading{}},
                @am2315 => %{temp: %Reading{}, rh: %Reading{}}}

  def kickstarted(%ServerState{} = s) do
    %ServerState{s | @kickstarted => status_tuple(@complete)}
  end

  def i2c_dev_exists?(%ServerState{} = s), do: s.i2c_dev_exists.status
  def confirm_i2c_dev(%ServerState{} = s) do
    dev_path = Path.join("/dev", I2cSensor.config(:i2c_device))
    case File.exists?(dev_path) do
      :true   -> %ServerState{s | @i2c_dev_exists =>
                        %{@ts => Timex.now(), @status => :true}}
      :false  -> %ServerState{s | @i2c_dev_exists =>
                        %{@ts => Timex.now(), @status => :false}}
    end
    # returns state
  end

  def available?(s) when is_map(s) do
    case s.available.status do
      :never -> :false
      :ok -> :true
      :failed -> :false
     end
  end
  def set_available(%ServerState{} = s), do: set_available(s, available?())
  defp set_available(%ServerState{} = s, a) do
    %ServerState{s | @available => status_tuple(a)}
  end
  defp available? do
    :ok
  end

  def set_pids(%ServerState{} = s, sht_pid, hih_pid, am2315_pid) do
    pids = %{@sht_pid => sht_pid,
              @hih_pid => hih_pid,
              @am2315_pid => am2315_pid}

    %ServerState{s | @pids => pids}
  end

  def clear_pids(%ServerState{} = s) do
    set_pids(s, :nil, :nil, :nil)
  end

  def get_sht_pid(%ServerState{} = s) do
    s.pids.sht_pid
  end

  def get_hih_pid(%ServerState{} = s) do
    s.pids.hih_pid
  end

  def get_am2315_pid(%ServerState{} = s), do: s.pids.am2315_pid

  def set_sensors(%ServerState{} = s, sensors) when is_list(sensors) do
    %ServerState{s | @sensors => sensors}
  end

  def get_sensors(%ServerState{} = s) do
    Enum.into(s.sensors, [], fn x -> x.name end)
  end

  def get_sensor_device(%ServerState{} = s, name) when is_binary(name) do
    sensor = Enum.find(s.sensors, fn x -> x.name == name end)
    sensor.device
  end

  def temp_cycle_start(%ServerState{} = s), do: set_temp_cycle(s, @in_progress)
  def temp_cycle_end(%ServerState{} = s),  do: set_temp_cycle(s, @complete)
  defp set_temp_cycle(%ServerState{} = s, v) do
    %ServerState{s | temp_cycle: status_tuple(v)}
  end
  def temp_cycle_recent?(%ServerState{} = s) do
    ts = s.temp_cycle.ts
    status = s.temp_cycle.status
    serial = temp_cycle_serial(s)

    res = Util.temp_cycle_recent?(ts, status, 1000)

    {res, serial}
  end
  def temp_cycle_serial(%ServerState{} = s) do
    s.temp_cycle.ts |> Timex.to_gregorian_microseconds() |> trunc
  end

  def set_sht_reading(%ServerState{} = s, r) when is_map(r) do
    set_reading(s, @sht, r)
  end

  def set_hih_reading(%ServerState{} = s, r) when is_map(r) do
    set_reading(s, @hih, r)
  end

  def set_am2315_reading(%ServerState{} = s, r) when is_map(r) do
    set_reading(s, @am2315, r)
  end

  defp set_reading(%ServerState{} = s, dev, r)
  when is_atom(dev) and is_map(r) do

    readings = %{s.readings | dev => r}
    %ServerState{s | @readings => readings}
  end

  def get_sht_reading(%ServerState{} = s), do: get_reading(s, @sht)
  def get_hih_reading(%ServerState{} = s), do: get_reading(s, @hih)
  def get_am2315_reading(%ServerState{} = s), do: get_reading(s, @am2315)

  def get_reading(%ServerState{} = s, dev) do
    s.readings[dev]
  end

  def put_temp_cycle_task(%ServerState{} = s, %Task{} = t) do
    %ServerState{s | @temp_cycle_task => t}
  end

  def clear_temp_cycle_task(%ServerState{} = s) do
    %ServerState{s | @temp_cycle_task => %Task{}}
  end

  def temp_cycle_idle?(%ServerState{} = s), do: s.temp_cycle_task.ref == :nil
  def temp_cycle_busy?(%ServerState{} = s), do: not temp_cycle_idle?(s)

  defp status_tuple(v), do: ts_tuple(@status, v)
  defp ts_tuple(k, v) when is_atom(k) do
    %{@ts => Timex.now, k => v}
  end

end
