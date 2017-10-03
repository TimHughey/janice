defmodule Mcp.Switch do
@moduledoc """
  The Switches module provides functionality for digital switches.

  Additionally, the Switches module handles the situation where a single
  addressable device has multiple siwtches.  For example, the DS2408 has
  eight PIOs available on each physical device.

  Behind the scenes a switch device id embeds the number of available PIOs and
  the specific PIO for friendly name.

  For example:
    ds/291d1823000000.08.01 => ds/<serial num>.<total pios>.<specific pio>
      * In other words, this device id addresses PIO one (of eight total)
        on the physical device with serial 291d1823000000.
      * The first two characters (or any characters before the slash) are
        a mnemonic identifiers for the type of physical device (most often
        the manufacturer or bus type).  In this case, 'ds' signals this is a
        device from Dallas Semiconductors.
"""

alias __MODULE__

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema
import Mcp.Repo, only: [get_by: 2, insert_or_update: 1]
import Ecto.Changeset, only: [change: 2]
import UUID, only: [uuid1: 0]

alias Mcp.DevAlias

def before_now do
  dt = Timex.to_datetime(Timex.now(), "UTC")
  Timex.shift(dt, hours: -3)
end

schema "switches" do
  field :device, :string
  field :enabled, :boolean, default: true
  field :states, {:array, :map}, default: []
  field :pending_cmds, {:array, :map}, default: []
  field :dt_last_cmd, Timex.Ecto.DateTime
  field :dt_discovered, Timex.Ecto.DateTime

  timestamps usec: true
end

def add_or_update(%Switch{} = s) do
  dev =
    case get_by(Switch, device: s.device) do
      nil -> s    # if not found then insert the switch passed in
      existing_dev -> existing_dev  # found, we'll just update
    end

  update = [dt_discovered: Timex.now()]

  {:ok, added} = dev |> change(update) |> insert_or_update
  added
end

@doc ~S"""
Get the state of a Switch via a friendly name

## Examples:
  iex> Mcp.Switch.state("test_pump1")
  true

  iex> Mcp.Switch.state("unknown")
  nil
"""

def state(friendly_name)
when is_binary(friendly_name) do
  DevAlias.get_by_friendly_name(friendly_name) |> state()
end

def state(%DevAlias{} = dev) do
  [unique_id, pio] = String.split(dev.device, ":", parts: 2)

  get_by(Switch, [device: unique_id]) |> state(pio)
end

# handle the situation where a friendly_name is not found or device name
# didn't parse into an unique name and pio
def state(nil), do: nil

def state(%Switch{} = s, pio)
when is_binary(pio) do
  state(s, String.to_integer(pio, 16))
end

def state(%Switch{} = s, pio) do
  internal_state(s.states, pio)
end

def state(_, nil), do: nil

defp internal_state(states, pio)
when is_list(states) and is_integer(pio) do
  case internal_state(hd(states), pio) do
    nil   -> internal_state(tl(states), pio)
    true  -> true     # the ACTUAL state of this Switch and pio
    false -> false
  end
end

# need to use strings as keys since that is how the map comes back from the
# database
defp internal_state(%{"pio" => pio, "state" => state}, requested_pio)
when pio == requested_pio do
  state
end

# if the above internal_state() didn't match then return nil to break out
# of the recursion
defp internal_state(%{"pio" => _pio, "state" => _state}, _requested_pio) do
  # Logger.info("pio=#{pio} state=#{state} requested_pio=#{requested_pio}")
  nil
end

# def get(friendly_name) when is_binary(friendly_name) do
#   case get_by(Switch, [friendly_name: friendly_name]) do
#     nil -> nil
#     s -> s
#   end
# end

# @doc ~S"""
# Set the pio (on / off) of a Switch
#
# ## Examples:
#   iex> state = true
#   ...> m = Mcp.Switches.set_state("water_pump", state)
#   ...> %{cmd_ref: cmd_ref, state: new_state} = m
#   ...> {String.valid?(cmd_ref.uuid),
#   ...>    Timex.is_valid?(cmd_ref.cmd_dt),
#   ...>    state === new_state}
#   {true, true, true}
# """
# def set_state(friendly_name, state)
# when is_boolean(state) and is_binary(friendly_name) do
#
#   s = get(friendly_name)
#   %{pending_cmds: cmds} = s
#
#   uuid = uuid1()
#   ts = Timex.now()
#   new_cmd = %{uuid: uuid, cmd_dt: ts}
#   cmds = [new_cmd | cmds]
#   updates = [state: state, pending_cmds: cmds, dt_last_cmd: Timex.now()]
#
#   {:ok, updated} = s |> change(updates) |> insert_or_update
#   [cmd_ref | _] = updated.pending_cmds
#   %{cmd_ref: cmd_ref, state: state}
# end
#
# @doc ~S"""
# Turn off a Switch
#
# ## Examples:
#   iex> m = Mcp.Switches.off("water_pump")
#   ...> %{cmd_ref: cmd_ref, state: new_state} = m
#   ...> {String.valid?(cmd_ref.uuid),
#   ...>   Timex.is_valid?(cmd_ref.cmd_dt), new_state}
#   {true, true, false}
# """
# def off(friendly_name)
# when is_binary(friendly_name) do
#   set_state(friendly_name, false)
# end
#
# @doc ~S"""
# Turn on a Switch
#
# ## Examples:
#   iex> Mcp.Switches.on("water_pump")
#   true
# """
# def on(friendly_name)
# when is_binary(friendly_name) do
#   updated = set_state(friendly_name, true)
#   updated.state
# end
#
# @doc ~S"""
# Retrieve the time a Switch was discovered
#
# ## Examples:
#   iex> Mcp.Switches.discovered("water_pump") |> Timex.is_valid?
#   true
#
#   iex> Mcp.Switches.discovered("unknown")
#   nil
# """
# def discovered(friendly_name) when is_binary(friendly_name) do
#   case get_by(Switches, [friendly_name: friendly_name]) do
#     nil -> nil
#     s -> s.dt_discovered
#   end
# end
#
# @doc ~S"""
# Add a new Switch
#
#
# @doc ~S"""
# Acknowledge a Switch command
#
# """
# def ack_cmd(friendly_name, uuid)
# when is_binary(friendly_name) and is_binary(uuid) do
#   s = get(friendly_name)
#
#   compare_uuid = fn cmd -> Map.get(cmd, "uuid") == uuid end
#
#   index = Enum.find_index(s.pending_cmds, compare_uuid)
#   ack_cmd_at_index(s, index)
# end
#
# defp ack_cmd_at_index(%Switches{}, index) when is_nil(index) do
#   {:nil, 0}
# end
#
# defp ack_cmd_at_index(%Switches{} = s, index) when is_integer(index) do
#   {cmd_to_ack, pending_cmds} = List.pop_at(s.pending_cmds, index)
#
#   updates = [pending_cmds: pending_cmds]
#   {:ok, _} = s |> change(updates) |> insert_or_update
#
#   acked_cmd_dt = Map.get(cmd_to_ack, "cmd_dt")
#   acked_uuid = Map.get(cmd_to_ack, "uuid")
#
#   latency = Timex.diff(Timex.now(), acked_cmd_dt)
#   {acked_uuid, latency}
# end
#
# @doc ~S"""
# Purge all pending commands from a Switch
#
# ## Examples:
#   iex> Mcp.Switches.purge_all_pending_cmds("water_pump")
#   :ok
# """
# def purge_all_pending_cmds(friendly_name) when is_binary(friendly_name) do
#   s = get(friendly_name)
#
#   updates = [pending_cmds: []]
#
#   {:ok, _} = s |> change(updates) |> insert_or_update
#   :ok
# end
#
# def friendly_name_from_raw_device(device, []), do: []
# def friendly_name_from_raw_device(device, [head | tail])
# when is_binary(device) do
#   [friendly_name_from_raw_device(device, head) |
#    friendly_name_from_raw_device(device, tail)]
# end
#
# def friendly_name_from_raw_device(device, position)
# when is_binary(device) and is_map(position) do
#   %{pio: pio, state: state} = position
#   friendly_name = "#{device}.#{pio}"
#   friendly_name
# end

end
