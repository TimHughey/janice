defmodule Dutycycle.Server do

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

  @moduledoc """
  GenServer implementation of Dutycycle controller capable of:
    - controlling a single device
    - to maintain temperature in alignment with reference
  """

  # require Logger
  # use GenServer
  # use Timex.Ecto.Timestamps
  # use Ecto.Schema
  # use Timex
  #
  # alias Switch
  # alias Ecto.Changeset
  # import Ecto.Query, only: [from: 2]
  # import Application, only: [get_env: 2]
  # import Keyword, only: [get: 3]
  # import Process, only: [cancel_timer: 1, send_after: 3]
  #
  # def start_link(args) do
  #   GenServer.start_link(McpDutycycle, args, name: Mcp.Dutycycle)
  # end
  #
  # @spec init(Map.t) :: {:ok, Map.t}
  # def init(s) when is_map(s) do
  #   state =
  #     %State{} |>
  #     State.kickstarted() |>
  #     State.set_known_dutycycles(get_all_dutycycles()) |>
  #     Kernel.struct(s)
  #
  #   autostart_ms =
  #     get_env(:mcp, Mcp.Dutycycle) |> get(:autostart_wait_ms, 1000)
  #
  #   case Map.get(s, :autostart, false) do
  #     true  -> if autostart_ms > 0 do
  #                send_after(self(), {:start}, autostart_ms)
  #              end
  #     false -> nil
  #   end
  #
  #   Logger.info("init()")
  #
  #   {:ok, state}
  # end
  #
  # @manual_start_msg {:manual_start}
  # def manual_start do
  #   GenServer.call(Mcp.Dutycycle, @manual_start_msg)
  # end
  #
  # def stop do
  #   GenServer.stop(Mcp.Dutycycle)
  # end
  #
  # def disabled_cycles do
  #   GenServer.call(Mcp.Dutycycle, {:get_disabled_cycles})
  # end
  #
  # def known_cycles do
  #   GenServer.call(Mcp.Dutycycle, @known_dutycycles_msg)
  # end
  #
  # @spec add(map) :: %Mcp.Dutycycle{}
  # def add(dutycycle)
  # when is_map(dutycycle) do
  #   Repo.insert(dutycycle)
  # end

end
