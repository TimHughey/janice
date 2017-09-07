defmodule Mcp.Util do

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

  use Timex
  @moduledoc :false

  def temp_cycle_recent?(ts, status, max_ms) do
    elapsed_ms = Timex.diff(Timex.now(), ts, :milliseconds)
    upper = trunc(max_ms * 0.75)

    case {elapsed_ms, status} do
      {x, :complete} when x < 0                 -> :false
      {x, :complete} when x >= 0 and x <= upper -> :true
      {x, :complete} when x >= 0 and x > upper  -> :false
      {_ignored, :never}                        -> :false
      {_ignored, :in_progress}                  -> :false
    end
  end

  def ns_to_ms(ns) when is_integer(ns), do: trunc(ns  / :math.pow(10,6))
  def ns_to_ms(ns) when is_float(ns), do: ns |> trunc() |> ns_to_ms()

  def ms_to_ns(ms) when is_integer(ms), do: trunc(ms * :math.pow(10,6))
  def ms_to_ns(ms) when is_float(ms), do: ms |> trunc() |> ms_to_ns()

  def us_to_ns(us) when is_integer(us), do: trunc(us * :math.pow(10,3))
  def us_to_ns(us) when is_float(us), do: us |> trunc() |> us_to_ns()

  def us_to_ms(us) when is_integer(us), do: trunc(us / :math.pow(10,3))
  def us_to_ms(us) when is_float(us), do: us |> trunc() |> us_to_ms()

  def now_ns, do: trunc(Timex.to_unix(Timex.now()) * :math.pow(10,9))
end
