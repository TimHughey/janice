defmodule Mcp.Influx.Position do
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
      Foo Foo Foundation
    """

    alias Elixir.DateTime
    alias Mcp.Influx
    alias Mcp.Influx.Position

    @on 0.2
    @null 0.0
    @off -0.2
    @at_ns :at_ns

    defstruct switch: "noswitch", pos: @null, at_ns: 0

    def new(n, p) when is_binary(n) and is_boolean(p) do
      new(n, p, now_ns())
    end
    def new(n, p, t) when is_binary(n) and is_boolean(p) and is_integer(t) do
      %Position{switch: n, pos: bool_to_pos(p), at_ns: t}
    end

    def on, do: @on
    def off, do: @off
    def null, do: @null

    def bool_to_pos(b) when is_boolean(b) do
      case b do
        :true -> @on
        :false -> @off
      end
    end

    def bool_to_pos(_), do: @null

    def post([]), do: :nil
    def post(l) when is_list(l) do
      post(hd(l))
      post(tl(l))
    end
    def post(%Position{} = p) do
      Influx.post(p)
    end

    def at_now(%Position{} = p), do: %Position{p | @at_ns => now_ns()}

    defp now_ns, do: DateTime.to_unix(DateTime.utc_now(), :nanosecond)
end
