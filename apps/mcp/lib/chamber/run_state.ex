defmodule Mcp.Chamber.RunState do
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
      This module implements the GenServer state for Chamber
    """

    require Logger
    use Timex

    alias __MODULE__
    alias Mcp.Chamber.Device

    @ts :ts
    @name :name

    defstruct name: "foobar", ts: Timex.zero(),
              heater: %Device{}, air_stir: %Device{}, mist: %Device{},
              fresh_air: %Device{}

    def create(name) when is_binary(name) do
      %RunState{@name => name, @ts => Timex.now()}
    end

    def name(%RunState{} = rs), do: rs.name

    @heater :heater
    def heater(%RunState{} = rs, ctrl_dev) when is_binary(ctrl_dev) do
      dev = Device.create(@heater, ctrl_dev)
      %RunState{rs | @heater => dev, @ts => Timex.now()}
    end

    def heater(%Device{} = dev, %RunState{} = rs) do
      %RunState{rs | @heater => dev, @ts => Timex.now()}
    end

    def heater(%RunState{} = rs, pos, t)
    when is_boolean(pos) and (is_reference(t) or t == :nil) do
      %RunState{rs | @heater => Device.position(rs.heater, pos, t),
                     @ts => Timex.now()}
    end

    def heater(%RunState{} = rs), do: rs.heater

    def heater_enabled?(%RunState{} = rs) do
      rs |> heater() |> Device.enabled?()
    end

    def heater_running?(%RunState{} = rs) do
      rs |> heater() |> Device.running?()
    end

    @air_stir :air_stir
    def air_stir(%RunState{} = rs, ctrl_dev) when is_binary(ctrl_dev) do
      dev = Device.create(@air_stir, ctrl_dev)
      %RunState{rs | @air_stir => dev, @ts => Timex.now()}
    end

    def air_stir(%Device{} = dev, %RunState{} = rs) do
      %RunState{rs | @air_stir => dev, @ts => Timex.now()}
    end

    def air_stir(%RunState{} = rs, pos, t)
    when is_boolean(pos) and (is_reference(t) or t == :nil) do
      %RunState{rs | @air_stir => Device.position(rs.air_stir, pos, t),
                     @ts => Timex.now()}
    end

    def air_stir(%RunState{} = rs), do: rs.air_stir

    def air_stir_enabled?(%RunState{} = rs) do
      rs |> air_stir() |> Device.enabled?()
    end

    def air_stir_idle?(%RunState{} = rs), do: air_stir_idle?(rs, 0)
    def air_stir_idle?(%RunState{} = rs, ms) do
      air_stir_idle?(rs, ms, Device.idling?(rs.air_stir))
    end
    def air_stir_idle?(%RunState{}, _ms, :false), do: false
    def air_stir_idle?(%RunState{} = rs, ms, :true) do
      diff = Timex.diff(Timex.now(), Device.ts(rs.air_stir), :milliseconds)

      case diff do
        x when x >= ms  -> :true
        x when x < ms   -> :false
      end
    end

    def air_stir_running?(%RunState{} = rs) do
      rs |> air_stir() |> Device.running?()
    end

    @mist :mist
    def mist(%RunState{} = rs, ctrl_dev) when is_binary(ctrl_dev) do
      dev = Device.create(@mist, ctrl_dev)
      %RunState{rs | @mist => dev, @ts => Timex.now()}
    end

    def mist(%Device{} = dev, %RunState{} = rs) do
      %RunState{rs | @mist => dev, @ts => Timex.now()}
    end

    def mist(%RunState{} = rs, pos, t)
    when is_boolean(pos) and (is_reference(t) or t == :nil) do
      %RunState{rs | @mist => Device.position(rs.mist, pos, t),
                     @ts => Timex.now()}
    end

    def mist(%RunState{} = rs), do: rs.mist

    def mist_enabled?(%RunState{} = rs) do
      rs |> mist() |> Device.enabled?()
    end

    def mist_idle?(%RunState{} = rs) do
      rs |> mist() |> Device.idling?()
    end

    def mist_running?(%RunState{} = rs) do
      rs |> mist() |> Device.running?()
    end

    def mist_state_elapsed?(%RunState{} = rs, ms) when is_integer(ms) do
      diff = Timex.diff(Timex.now(), Device.ts(rs.mist), :milliseconds)

      case diff do
        x when x >= ms -> :true
        x when x < ms  -> :false
      end
    end

    @fresh_air :fresh_air
    def fresh_air(%RunState{} = rs, ctrl_dev) when is_binary(ctrl_dev) do
      dev = Device.create(@fresh_air, ctrl_dev)
      %RunState{rs | @fresh_air => dev, @ts => Timex.now()}
    end

    def fresh_air(%Device{} = dev, %RunState{} = rs) do
      %RunState{rs | @fresh_air => dev, @ts => Timex.now()}
    end

    def fresh_air(%RunState{} = rs, pos, t)
    when is_boolean(pos) and (is_reference(t) or t == :nil) do
      %RunState{rs | @fresh_air => Device.position(rs.fresh_air, pos, t),
                     @ts => Timex.now()}
    end

    def fresh_air(%RunState{} = rs), do: rs.fresh_air

    def fresh_air_enabled?(%RunState{} = rs) do
      rs |> fresh_air() |> Device.enabled?()
    end

    def fresh_air_idle?(%RunState{} = rs), do: fresh_air_idle?(rs, 0)
    def fresh_air_idle?(%RunState{} = rs, ms) do
      fresh_air_idle?(rs, ms, Device.idling?(rs.fresh_air))
    end
    defp fresh_air_idle?(%RunState{}, _ms, :false), do: false
    defp fresh_air_idle?(%RunState{} = rs, ms, :true) do
      diff = Timex.diff(Timex.now(), Device.ts(rs.fresh_air), :milliseconds)

      case diff do
        x when x >= ms  -> :true
        x when x < ms   -> :false
      end
    end

    #
    # Per device functions
    #

    def disable_all(%RunState{} = rs) do
      %RunState{rs | @heater => Device.disable(rs.heater),
                     @air_stir => Device.disable(rs.air_stir),
                     @mist => Device.disable(rs.mist),
                     @fresh_air => Device.disable(rs.fresh_air),
                     @ts => Timex.now()}
    end

    def disabled?(%RunState{} = rs), do: not enabled?(rs)
    def enabled?(%RunState{} = rs) do
      heater_enabled?(rs) and air_stir_enabled?(rs) and
        mist_enabled?(rs) and fresh_air_enabled?(rs)
    end

    def idle_all(%RunState{} = rs) do
      %RunState{rs | @heater => Device.idle(rs.heater, :nil),
                     @air_stir => Device.idle(rs.air_stir, :nil),
                     @mist => Device.idle(rs.mist, :nil),
                     @fresh_air => Device.idle(rs.fresh_air, :nil),
                     @ts => Timex.now()}
    end
end
