defmodule Mcp do

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

  @moduledoc :false

  use Application
  require Logger

  def start(_type, _args) do
    for node <- Application.get_env(:mcp, :connect_nodes) do
      if Node.connect(node) == :false do
        Logger.debug("failed to connect node #{node}")
      end
    end

    Mcp.Supervisor.start_link([])
  end
end
