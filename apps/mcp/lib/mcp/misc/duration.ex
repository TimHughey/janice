defmodule Mcp.Duration do
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
    This module implements a Duration record
  """
    use Timex

    alias Mcp.Duration

    @metric :metric
    @value :value
    @ts :ts

    defstruct metric: "nometric", value: 0.0, ts: Timex.zero()

    def create(m, v) when is_binary(m) and is_number(v) do
      %Duration{metric: m, value: v, ts: Timex.now()}
    end

    def metric(%Duration{@metric => m}), do: m
    def val(%Duration{@value => v}), do: v
    def ts(%Duration{@ts => ts}), do: ts
    def ts_ns(%Duration{@ts => ts}) do
      Timex.to_unix(ts) * trunc(:math.pow(10,9))
    end
end
