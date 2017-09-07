defmodule Mcp.Supervisor do

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

  use Supervisor
  require Logger
  @moduledoc :false

  def start_link(arg) do
    Supervisor.start_link(Mcp.Supervisor, arg, name: Mcp.Supervisor)
  end

  def init(_arg) do
    children = all_children(Application.get_env(:mcp, :autostart))

    opts =
      [strategy: :one_for_all] ++ config(__MODULE__, :opts)

    supervise(children, opts)
  end

  # the following should be used for :test and :prod envs
  # and is controlled by the configuration of :mcp :autostart
  defp all_children(:true) do
    [supervisor(Mcp.Repo, []),
     worker(Mcp.Influx, [%{}]),
     supervisor(Mcp.Owfs.Supervisor, [%{}]),
     worker(Mcp.Switch, [%{}]),
     supervisor(Mcp.I2cSensor.Supervisor, [%{}]),
#     worker(Mcp.SensorScribe, [%{}]),
#     worker(Mcp.Proxr, [%{}]),
#     worker(Mcp.ProxrBoy, [%{}]),
     worker(Mcp.Mixtank, [%{}]),
     worker(Mcp.Dutycycle, [%{}]),
     worker(Mcp.Chamber, [%{}])]
  end

  defp all_children(:false), do: []

  def server_status, do: :sys.get_status(server_name())
  def get_status, do: :sys.get_status(server_name())
  def get_state, do: :sys.get_state(server_name())

  def config(mod, key) do
    Application.get_env(:mcp, :genservers)[mod][key]
  end

  def server_name, do: :supervisor

  def config do
    name = {:local, :supervisor}

    %{:Supervisor =>
      %{:prod => %{name: name, opts: [max_restarts: 3, max_seconds: 5]},
        :test => %{name: name, opts: [max_restarts: 1, max_seconds: 1]},
        :dev =>  %{name: name, opts: [max_restarts: 0, max_seconds: 1]}}}
  end

end
