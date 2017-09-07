defmodule Mcp.ProxrBoy do

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
  alias Mcp.Proxr

  defmodule State do
    @moduledoc :false

    defstruct ping: {Timex.zero(), :never},
      relays: %{1 => :nil, 2 => :nil, 3 => :nil,
                4 => :nil, 5 => :nil, 6 => :nil,
                7 => :nil, 8 => :nil},
      analog: %{1 => :nil, 2 => :nil, 3 => :nil,
                4 => :nil, 5 => :nil, 6 => :nil,
                7 => :nil, 8 => :nil},
      temp_F:   {Timex.zero(), :never},
      temp_C:   {Timex.zero(), :never},
      last_relay_set: {Timex.zero(), :never},
      last_read_all: {Timex.zero(), :never},
      last_analog: {Timex.zero(), :never}
  end

  defp call_timeout_ms, do: config(:call_timeout_ms)

  def start_link(_args) do
    start_link(__MODULE__, config(:name), %State{})
  end

  @spec init(%State{}) :: {:ok, %State{}}
  def init(%State{} = state) do
    state = schedule_read(state, config(:kickstart_wait_ms))

    {:ok, state}
  end

  @spec release :: :ok
  def release do
    GenServer.cast(server_name(), :release)
  end

  @spec all_off :: :proxr_all_off_success
  def all_off do
    GenServer.call(server_name(), {:all_off}, call_timeout_ms())
  end

  def change(relay, position)
  when is_binary(relay) and is_boolean(position) do
    change(String.to_integer(relay), position)
  end

  def change(relay, position)
  when is_integer(relay) and is_boolean(position) do
    msg =
      case position do
        :true  -> {:relay_set, relay, :true}
        :false -> {:relay_set, relay, :false}
      end

    GenServer.call(server_name(), msg, call_timeout_ms())
  end

  def position(relay) when is_integer(relay) do
    GenServer.call(server_name(), {:relay_get, relay}, call_timeout_ms())
  end

  @spec position(1..7) :: true | false
  def position(relay) when is_binary(relay) do
    position(String.to_integer(relay))
  end

  @spec analog(1..7) :: float
  def analog(num)
  when is_integer(num) and num >= 1 and num <= 7 do
    GenServer.call(server_name(), {:analog_get, num}, call_timeout_ms())
  end

  @spec faren :: float
  def faren do
    {_ts, temp_f} = GenServer.call(server_name(), {:temp_F}, call_timeout_ms())

    temp_f
  end

  @spec ping :: {:ok, {:pong}} | {:error, {any}}
  def ping do
    GenServer.call(server_name(), {:ping}, call_timeout_ms())
  end

  @spec handle_call({:all_off}, pid, %State{}) ::
    {:reply, {:ok, :proxr_all_off_success}}
  def handle_call({:all_off}, _from, state) do
    {:ok, {:ok, result}} = Proxr.all_off()

    state = %{state | last_relay_set: state_tuple(:success)}

    {:reply, result, state}
  end

  def handle_call({:relay_set, relay, position}, _from, state) do
    relays = %{state.relays | relay => position}

    byte =
      for {relay, pos} <- relays do
        case pos do
          x when x == true -> (0x01 <<< (relay - 1))
          _x -> 0x00
        end
      end |> List.foldr(0, fn(x, acc) -> x + acc end)

    {:ok, {:ok, result}} = Proxr.set_relays(byte)

    state = %{state | relays: relays}
    state = %{state | last_relay_set: state_tuple(:success)}

    {:reply, result, state}
  end

  def handle_call({:relay_get, relay}, _from, state) do
    {:reply, {:ok, state.relays[relay]}, state}
  end

  def handle_call({:analog_get, num}, _from, state) do
    {:reply, state.analog[num], state}
  end

  def handle_call({:temp_F}, _from, state) do
    {:reply, state.temp_F, state}
  end

  def handle_call({:ping}, _from, state) do
    result = Proxr.ping()

    tuple =
      case Proxr.ping() do
        {:ok, :pong} -> state_tuple(:success)
        _            -> state_tuple(:failed)
      end

    state = %{state | ping: tuple}

    {:reply, result, state}
  end

  def handle_cast(:release, state) do
    {:stop, :normal, state}
  end

  def handle_info({:scheduled_read}, state) do
    {:ok, {:relay_positions, relays_byte}} = Proxr.read_relays()

    relays =
      for {relay, _pos} <- state.relays do
        position =
          case ((0x01 <<< (relay - 1)) &&& relays_byte) do
            x when x > 0 -> :true
            x when x == 0 -> :false
          end
        {relay, position}
      end |> Enum.into(%{})

    state = %State{state | relays: relays}
    state = %State{state | last_read_all: state_tuple(:success)}

    Process.send_after(self(), {:scheduled_analog}, 10)

    {:noreply, state}
  end

  def handle_info({:scheduled_analog}, state) do
    {:ok, {:analog_readings, analog_values}} = Proxr.read_analog()

    analogs = Range.new(1, 8) |> Enum.zip(analog_values) |> Enum.into(%{})

    temp_raw = analogs[8]
    temp_c = Float.round(((temp_raw - 490.0) / 19.5), 3)
    temp_f = Float.round((temp_c * (9.0 / 5.0) + 32.0), 3)

    state = %State{state | analog: analogs}
    state = %State{state | last_analog: state_tuple(:success)}
    state = %State{state | temp_C: state_tuple(temp_c)}
    state = %State{state | temp_F: state_tuple(temp_f)}

    state = %State{state | last_analog: state_tuple(:success)}

    Process.send_after(self(), {:scheduled_read}, config(:refresh_ms))

    {:noreply, state}
  end

  defp schedule_read(%State{} = state, next_ms) do
    Process.send_after(self(), {:scheduled_read}, next_ms)

    state
  end

  defp sys_time, do: Timex.now()
  defp state_tuple(:success), do: {sys_time(), :success}
  defp state_tuple(:never), do: {Timex.zero(), :never}
  defp state_tuple(val) when is_binary(val), do: {sys_time(), val <> <<0x00>>}
  defp state_tuple(val) when is_integer(val), do: {sys_time(), Integer.to_charlist(val, 2)}
  defp state_tuple(val), do: {sys_time(), val}

end
