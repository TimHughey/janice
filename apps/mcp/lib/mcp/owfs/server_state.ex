defmodule Mcp.Owfs.ServerState do
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

  alias __MODULE__

  alias Mcp.Owfs
  alias Mcp.Util

  @ts :ts
  @status :status
  @kickstarted :kickstarted
  @available :available
  @temp_cycle :temp_cycle
  @temp_cycle_task :temp_cycle_task
  @buses :buses
  @never :never
  @pid_path "system/process/pid"
  @status :status
  @num :num
  @complete :complete
  @in_progress :in_progress

  defstruct kickstarted: %{@ts =>Timex.zero, @status => @never},
    available: %{@ts => Timex.zero, @status => @never},
    temp_cycle: %{@ts => Timex.zero, @status => @never},
    temp_cycle_task: %Task{},
    buses:  %{@ts => Timex.zero, @num => 0}

  def kickstarted(%ServerState{} = s) do
    %ServerState{s | @kickstarted => status_tuple(@complete)}
  end

  def available?(%ServerState{} = s) do
    case s.available.status do
      :never -> :false
      :ok -> :true
      :failed -> :false
     end
  end
  def set_available(s), do: set_available(s, available?())
  defp set_available(s, a) do
    %ServerState{s | @available => status_tuple(a)}
  end
  defp available? do
    case owfs_pid() do
      {:ok, _pid} -> :ok
      {:error, _reason} -> :failed
    end
  end
  defp owfs_pid do
    path = Path.join(Owfs.config(:path), @pid_path)

    with {:ok, binary}    <- File.read(path),
         {pid, _leftover} <- Integer.parse(binary), do: {:ok, pid}
  end

  def num_buses(s) when is_map(s) , do: s.buses.num
  def set_num_buses(s, n) when is_map(s) and is_integer(n) do
    %ServerState{s | @buses => ts_tuple(@num, n)}
  end

  def temp_cycle_start(s) when is_map(s), do: set_temp_cycle(s, @in_progress)
  def temp_cycle_end(s) when is_map(s),  do: set_temp_cycle(s, @complete)
  defp set_temp_cycle(s, v) do
    %ServerState{s | @temp_cycle => status_tuple(v)}
  end
  def temp_cycle_recent?(%ServerState{} = s) do
    ts = s.temp_cycle.ts
    status = s.temp_cycle.status
    upper = Owfs.recommended_next_temp_ms()
    serial = temp_cycle_serial(s)

    res = Util.temp_cycle_recent?(ts, status, upper)

    {res, serial}
  end
  def temp_cycle_serial(s) when is_map(s) do
    s.temp_cycle.ts |> Timex.to_gregorian_microseconds() |> trunc
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
