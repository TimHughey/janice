defmodule Mcp.Proxr do

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
  Serial communication through Elixir ports.
  """

  require Logger
  use Mcp.GenServer
  use Bitwise
  use Timex

  defmodule State do
    @moduledoc :false

    defstruct port: :nil,
      ping: {Timex.zero(), :never}
  end

  defp call_timeout_ms, do: config(:call_timeout_ms)

  def start_link(_args) do
    start_link(Mcp.Proxr, config(:name), %State{})
  end

  def init(%State{} = state) do
    state =
      case File.exists?(config(:relay_dev)) do
        :true  -> setup_port(state)
        :false -> %State{port: nil}
      end

    {:ok, state}
  end

  @spec release :: :ok
  def release do
    GenServer.cast(server_name(), :release, call_timeout_ms())
  end

  def ping do
    GenServer.call(server_name(), :ping, call_timeout_ms())
  end

  @spec read_relays :: {:ok, {:ok, integer}}
  def read_relays do
    GenServer.call(server_name(), :read_relays, call_timeout_ms())
  end

  def set_relays(relay_positions)
  when is_integer(relay_positions) do
    msg = {:set_relays, relay_positions}
    GenServer.call(server_name(), msg, call_timeout_ms())
  end

  def read_analog do
    GenServer.call(server_name(), :read_analog, call_timeout_ms())
  end

  def all_off do
    GenServer.call(server_name(), :all_off, call_timeout_ms())
  end

  def handle_call(:ping, _from, state) do
    result = call_port(state, {:ping, 0})

    state =
      case result do
        {:ok, :pong} -> %State{state | ping: state_tuple(:success)}
        _error       -> %State{state | ping: state_tuple(:failed)}
      end

    {:reply, result, state}
  end

  def handle_call(:read_relays, _from, state) do
    result = call_port(state, {:read_relays, 0})
    {:reply, result, state}
  end

  def handle_call({:set_relays, positions}, _from, state) do
    result = call_port(state, {:set_relays, positions})
    {:reply, result, state}
  end

  def handle_call(:read_analog, _from, state) do
    result = call_port(state, {:read_analog, 0})
    {:reply, result, state}
  end

  def handle_call(:all_off, _from, state) do
    result = call_port(state, {:all_off, 0})
    {:reply, result, state}
  end

  def handle_cast(:release, state) do
    {:stop, :normal, state}

  end

  def handle_info(_port, {:data, raw}, state) do
    Logger.warn("spruious data #{raw}")
    {:noreply, state}
  end

  defp setup_port(%State{} = state) do
    exec = :code.priv_dir(:mcp) ++ '/proxr'
    dev = config(:relay_dev)
    args = [{:args, ['proxr', dev]},
              :binary,
              {:packet, 2},
              :use_stdio,
              :exit_status]

    port = Port.open({:spawn_executable, exec}, args)
    state = %State{state | port: port}

    # for safety, let's always turn off all relays at start up
    {:ok, {_, _}} = call_port(state, {:all_off, 0})

    state
  end

  defp sys_time, do: Timex.now()
  defp state_tuple(val), do: {sys_time(), val}

  # Private helper functions
  defp call_port(%State{port: :nil}, {_command, _arguments}) do
    Logger.warn("Mcp.Proxr.call_port invoked with nil port.")
    {:error, :call_port}
  end

  defp call_port(%State{} = state, {command, arguments}) do
    msg = {command, arguments}
    send state.port, {self(), {:command, :erlang.term_to_binary(msg)}}
    receive do
      {_, {:data, response}} -> {:ok, :erlang.binary_to_term(response)}
      _ -> {:error, :call_port}
    end
  end
end
