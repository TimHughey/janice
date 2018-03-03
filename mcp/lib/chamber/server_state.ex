defmodule Mcp.Chamber.ServerState do
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
    This module implements the GenServer state for Chamber
  """

  require Logger
  use Timex

  alias __MODULE__
  alias Mcp.Chamber.RunState

  @kickstarted :kickstarted
  @known_chambers :known_chambers
  @chambers :chambers
  @routine_check :routine_check

  @ts :ts
  @status :status
  @names :names

  @ok :ok
  @never :never
  @complete :complete

  defstruct kickstarted: %{@ts => Timex.zero(), @status => @never},
            known_chambers: %{@ts => Timex.zero(), @names => []},
            chambers: %{},
            routine_check: %{@ts => Timex.zero(), @status => @never},
            autostart: false

  # chamber run state example:
  #   "name" => %{  heater: %Device{},
  #                 fresh_air: %Device{} }
  #

  def known_chambers(%ServerState{} = s), do: s.known_chambers.names

  def known_chambers(%ServerState{} = s, n) when is_list(n) do
    s = clean_orphans(s, n, s.known_chambers.names)

    kc = %{@ts => Timex.now(), @names => n}
    s = %ServerState{s | @known_chambers => kc}
    chambers(s, n)
  end

  defp clean_orphans(%ServerState{} = s, new, old)
       when is_list(new) and is_list(old) do
    clean_orphans(s, old -- new, :log)
  end

  defp clean_orphans(%ServerState{} = s, [], :log), do: s

  defp clean_orphans(%ServerState{} = s, orphans, :log)
       when is_list(orphans) do
    msg = Enum.join(orphans, ", ")
    Logger.info(fn -> "Chamber detected orphans [#{msg}] -- will clean" end)
    clean_orphans(s, orphans)
  end

  defp clean_orphans(%ServerState{} = s, []), do: s

  defp clean_orphans(%ServerState{} = s, orphans)
       when is_list(orphans) do
    s |> clean_orphans(hd(orphans)) |> clean_orphans(tl(orphans))
  end

  defp clean_orphans(%ServerState{} = s, orphan)
       when is_binary(orphan) do
    %ServerState{s | @chambers => Map.delete(s.chambers, orphan)}
  end

  defp chambers(%ServerState{} = s, []), do: s

  defp chambers(%ServerState{} = s, names) when is_list(names) do
    s |> chambers(hd(names)) |> chambers(tl(names))
  end

  defp chambers(%ServerState{} = s, name) when is_binary(name) do
    run_state = RunState.create(name)
    chambers = Map.put_new(s.chambers, name, run_state)
    %ServerState{s | @chambers => chambers}
  end

  def run_state(nil, %ServerState{} = s), do: s

  def run_state(%ServerState{} = s, n) when is_binary(n) do
    s.chambers[n]
  end

  def run_state(name, %ServerState{} = s) when is_binary(name) do
    s.chambers[name]
  end

  def run_state(%RunState{} = rs, %ServerState{} = s) do
    c = Map.put(s.chambers, rs.name, rs)
    %ServerState{s | @chambers => c}
  end

  def record_routine_check(%ServerState{} = s) do
    %ServerState{s | @routine_check => status_tuple(@ok)}
  end

  def kickstart(%ServerState{} = s) do
    %ServerState{s | @kickstarted => status_tuple(@complete)}
  end

  def kickstarted?(%ServerState{@kickstarted => @complete}), do: true
  def kickstarted?(%ServerState{@kickstarted => @never}), do: false

  defp status_tuple(v), do: ts_tuple(@status, v)

  defp ts_tuple(k, v) when is_atom(k) do
    %{@ts => Timex.now(), k => v}
  end
end
