defmodule Mcp.Switch do

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
  GenServer implementation of Switch capable of:
    - reading switch states
    - setting switch states
  """

  require Logger
  use Ecto.Schema
  use Timex.Ecto.Timestamps
  use Mcp.GenServer
  use Timex

  alias __MODULE__
  alias Mcp.Owfs
  alias Mcp.Relay
  alias Mcp.Repo
  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Mcp.Util

  defmodule State do
    @moduledoc :false

    @never :never
    @ts :ts
    @kickstarted :kickstarted
    @known_switches :known_switches
    @read_cycle :read_cycle
    @ms :ms
    @names :names
    @count :count
    @status :status
    @complete :complete
    # @in_progress :in_progress

    defstruct kickstarted: %{@ts =>Timex.zero, @status => @never},
      known_switches: %{@ts => Timex.zero, @names => [], @count => 0},
      read_cycle: %{@ts => Timex.zero, @ms => 0}

    def kickstarted(%State{} = state) do
      %State{state | @kickstarted => status_tuple(@complete)}
    end

    def set_known_switches_names(%State{} = state, n) when is_list(n) do
      ks = %{@ts => Timex.now(), @names => n, @count => Enum.count(n)}
      %State{state | @known_switches => ks}
    end
    def known_switches_names(%State{} = state) do
      state.known_switches.names
    end
    def known_switches_count(%State{} = state), do: state.known_switches.count

    def set_read_cycle_ms(%State{} = state, n) when is_integer(n) do
      %State{state | @read_cycle => ts_tuple(@ms, n)}
    end
    def read_cycle_ms(%State{} = state), do: state.read_cycle.ms

    defp status_tuple(v), do: ts_tuple(@status, v)
    defp ts_tuple(k, v) when is_atom(k) do
      %{@ts => Timex.now, k => v}
    end
  end

  # known providers
  @owfs "owfs"
  @proxr "proxr"

  schema "switches" do
    field :name, :string, default: :nil
    field :description, :string
    field :provider, :string, default: @owfs
    field :group, :string
    field :pio, :string
    field :position, :boolean, default: false
    field :position_at, Timex.Ecto.DateTime

    timestamps usec: true
  end

  @change_msg :change
  @position_msg :position
  @routine_update_msg :routine_update
  @shutdown_msg :shutdown

  @doc """
  Traditional start_link
  """
  def start_link(_args) do
    start_link(Mcp.Switch, config(:name), %State{})
  end

  def init(state) when is_map(state) do
    state = State.kickstarted(state)
    auto_populate()
    Process.send_after(self(), @routine_update_msg, kickstart_wait_ms())

    {:ok, state}
  end

  def stop do
    GenServer.stop(server_name())
  end

  def add(%Switch{provider: @owfs} = sw) when is_map(sw) do
    sw =
      case Owfs.get_switch_position(sw.group, sw.pio) do
        {:ok, sw_position} -> %Mcp.Switch{sw | position: sw_position}
        {:error, _reason} -> %Mcp.Switch{sw | position: :nil}
      end

    sw = %Mcp.Switch{sw | position_at: Timex.now()}

    Repo.insert(sw)
  end

  def add(%Switch{provider: @proxr} = sw)
  when is_map(sw) do
    sw =
      case Relay.position(sw.pio) do
        {:ok, sw_position} -> %Mcp.Switch{sw | position: sw_position}
        {:error, _reason} -> %Mcp.Switch{sw | position: :nil}
      end

    sw = %Mcp.Switch{sw | position_at: Timex.now()}

    Repo.insert(sw)
  end

  defp default_switches do
     [%Switch{name: "basement_fan", group: "systronix_p1", pio: "PIO.A"},
      %Switch{name: "mixtank_heater", group: "systronix_p2", pio: "PIO.A"},
      %Switch{name: "loop_indicator", group: "systronix_p3", pio: "PIO.A"},
      %Switch{name: "buzzer", group: "systronix_buzzer", pio: "PIO.A"},
      %Switch{name: "sump_vent", group: "io_relay1", pio: "PIO.0"},
      %Switch{name: "mixtank_air", group: "io_relay1", pio: "PIO.1"},
      %Switch{name: "mixtank_pump", group: "io_relay1", pio: "PIO.2"},
      %Switch{name: "reefmix_rodi_valve", group: "io_relay1", pio: "PIO.3"}]
#       %Switch{name: "proxr_test", provider: @proxr, group: "1", pio: "2"} ]
  end

  def auto_populate do
    query = from s in Switch, select: s.id
    db_count  = query |> Repo.all() |> Enum.count
    def_count = Enum.count(default_switches())

    switches =
      case db_count do
        x when x < def_count -> default_switches()
        _rest -> []
    end

    for switch <- switches do
      switch |> load() |> persist_with_position(:false)
    end |> Enum.count
  end

  defp load(%Switch{name: :nil}), do: :nil
  defp load(%Switch{} = switch) do
    case Repo.get_by Switch, name: switch.name do
      :nil   -> switch
      found  -> found
    end
  end

  defp persist_with_position(%Switch{name: :nil}, _position), do: :nil
  defp persist_with_position(%Switch{} = switch, position)
  when is_boolean(position) do
    cs = Changeset.change switch, %{position: position, position_at: Timex.now}
    cs = Changeset.unique_constraint cs, :name

    Repo.insert_or_update cs
  end

  defp do_refresh_all(%State{} = state) do
    all_switches = Repo.all(Mcp.Switch)

    for sw <- all_switches do
      case sw do
        :nil -> :nil
        s -> refresh_position(s.name)
      end
    end

    State.set_known_switches_names(state, all_switches)
  end

  defp get(name) when is_binary(name), do: Repo.get_by(Mcp.Switch, [name: name])

  def refresh_position({:ok, name}), do: refresh_position(name)
  def refresh_position({:error, _name}), do: refresh_position(:nil)
  def refresh_position(:nil), do: :nil
  def refresh_position("foobar") do
    Logger.warn("Switch: refresh_position(\"foobar\") called!")
    :nil 
  end
  def refresh_position(name) when is_binary(name) do
    name |> get() |> update_position() |> Repo.insert_or_update()
  end

  defp update_position(:nil), do: :nil
  defp update_position(%Switch{provider: @owfs} = sw) do
    at = Timex.now()

    case Owfs.get_switch_position(sw.group, sw.pio) do
      {:ok, position} -> Changeset.change(sw,
                          %{position: position, position_at: at})
      {:error, _r} -> Changeset.change(sw,
                          %{position: :nil, position_at: at})
    end
  end

  defp update_position(%Switch{provider: @proxr} = sw) do
    at = Timex.now()

    case Relay.position(sw.pio) do
      {:ok, position} -> Changeset.change(sw,
                            %{position: position, position_at: at})
      {:pending, _}  -> Changeset.change(sw)
    end
  end

  def position("foobar") do
    Logger.warn("Switch.position() called with foobar")
    :nil
  end
  def position(:nil) do
    Logger.warn("Switch.position() called with :nil")
    :nil
  end
  def position(name) do
    GenServer.call(server_name(), {@position_msg, name})
  end

  def position("fobar", _any), do: position("foobar")
  def position(:nil, _any), do: position(:nil)
  def position(name, position)
  when is_binary(name) and is_atom(position) do
    change(name, position)
  end

  defp do_position(:nil), do: :nil
  defp do_position(name)
  when is_binary(name) do
    case get(name) do
      :nil -> {:error, name}
      sw -> {:ok, sw.position}
    end
  end

  def change(:nil, _position), do: :nil
  def change(name, position)  do
    GenServer.call(server_name(), {@change_msg, name, position})
  end

  def change(:nil, _position, :cast), do: :nil
  def change(name, position, :cast) do
    GenServer.cast(server_name(), {@change_msg, name, position})
  end

  defp do_change(:nil, _position), do: :nil
  defp do_change(name, position) when is_binary(name) do
    name |> get() |> do_change(position)

    refresh_position(name)
  end

  defp do_change(%Switch{provider: @owfs} = sw, position) do
    Owfs.switch_set(sw.group, sw.pio, position)
  end

  defp do_change(%Switch{provider: @proxr} = sw, position) do
    Relay.change(sw.pio, position)
  end

  defp do_change(%Switch{} = sw, _position) do
    Logger.error("Switch #{sw.name} -> unknown provider: #{sw.provider}")
    sw
  end

  defp do_routine_update(state) do
    {elapsed_us, state} = :timer.tc(&do_refresh_all/1, [state])

    elapsed_ms = us_to_ms(elapsed_us)

    Process.send_after(self(), @routine_update_msg, refresh_ms())

    _state = State.set_read_cycle_ms(state, elapsed_ms)
  end

  def handle_call(@shutdown_msg, _from, state) do
    {:stop, :graceful, state}
  end

  def handle_call({@position_msg, name}, _from, state) do
    {:reply, do_position(name), state}
  end

  def handle_call({@change_msg, :nil, _position}, _from, state), do: {:reply, :nil, state}
  def handle_call({@change_msg, name, position}, _from, state) do
    {:reply, do_change(name, position), state}
  end

  def handle_cast({@change_msg, :nil, _position}, state), do: {:noreply, state}
  def handle_cast({@change_msg, name, position}, state) do
    _ignored = do_change(name, position)
    {:noreply, state}
  end

  def handle_info(@routine_update_msg, state) do
    {:noreply, do_routine_update(state)}
  end

  def any_switches? do
    count = all_ids() |> Enum.count

    case count do
      x when x > 0 -> :true
      _rest        -> :false
    end
  end

  defp all_ids do
    query = from s in Switch, select: s.id

    Repo.all query
  end

  def purge_all(:for_real) do
    for id <- all_ids() do
      switch = Repo.get_by(Switch, id: id)
      Repo.delete switch
    end |> Enum.count
  end

  # configuration helpers
  @kickstart_wait_ms :kickstart_wait_ms
  @refresh_ms :refresh_ms

  defp kickstart_wait_ms, do: config(@kickstart_wait_ms)
  defp refresh_ms, do: config(@refresh_ms)

end
