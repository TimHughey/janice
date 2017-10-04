defmodule Mcp.Switch do
@moduledoc """
  The Switches module provides functionality for digital switches.

  Additionally, the Switches module handles the situation where a single
  addressable device has multiple siwtches.  For example, the DS2408 has
  eight PIOs available on each physical device.

  Behind the scenes a switch device id embeds the specific PIO
  for a friendly name.

  For example:
    ds/291d1823000000:1 => ds/<serial num>:<specific pio>
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

import Application, only: [get_env: 2]
import UUID, only: [uuid1: 0]
import Ecto.Changeset, only: [change: 2]

import Mcp.Repo, only: [get_by: 2, insert_or_update: 1]

#import Mqtt.Client, only: [publish_switch_cmd: 1]

alias Command.SetSwitch
alias Mcp.DevAlias
alias Mqtt.Client

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

def add_or_update(unique_id)
when is_binary(unique_id) do
  %Switch{device: unique_id} |> add_or_update()
end

def add_or_update(%Switch{} = s) do
  dev =
    case get_by(Switch, device: s.device) do
      nil -> s    # if not found then insert the switch passed in
      existing_dev -> existing_dev  # found, we'll just update
    end

  update = [dt_discovered: Timex.now()]

  {:ok, added} = dev |> change(update) |> insert_or_update

  # get the friendly name to ensure a DevAlias exists or created
  _friendly_names = get_friendly_names(added)
  added
end

def acknowledge_cmd({unique_id, states, refid, latency})
when is_binary(unique_id) and
  is_list(states) and
  is_binary(refid) and
  is_number(latency) do

  sw = get_by_unique_name(unique_id)

  index = Enum.find_index(sw.pending_cmds,
            fn(x) -> Map.get(x, "refid") === refid end)

  result = ack_cmd_at_index(sw, states, index)

  if config(:logCmdAck) do
    {acked_refid, rt_latency} = result
    Logger.info("acked refid: #{acked_refid} dev: #{as_ms(latency)} " <>
                "rt: #{as_ms(rt_latency)}")
  end

  result
end

defp ack_cmd_at_index(%Switch{}, _, index) when is_nil(index) do
  {:nil, 0}
end

defp ack_cmd_at_index(%Switch{} = s, states, index)
when is_list(states) and is_integer(index) do
  {cmd_to_ack, pending_cmds} = List.pop_at(s.pending_cmds, index)

  updates = [pending_cmds: pending_cmds, states: states]
  {:ok, _} = s |> change(updates) |> insert_or_update

  {:ok, acked_cmd_dt} = Map.get(cmd_to_ack, "cmd_dt") |>
                  Timex.parse("{ISO:Extended}")
  acked_uuid = Map.get(cmd_to_ack, "refid")

  rt_latency = Timex.diff(Timex.now(), acked_cmd_dt)
  {acked_uuid, rt_latency}
end

def set_state(friendly_name, pos)
when is_binary(friendly_name) and is_boolean(pos) do
  Logger.metadata(switch_friendly_name: friendly_name)

  get_by_friendly_name(friendly_name) |>
    device_name_and_pio() |>
    get_by_unique_name() |>
    set_state(pos)
end

def set_state({%Switch{pending_cmds: cmds, states: states} = sw, pio}, pos)
when is_boolean(pos) do
  new_states = update_pio_state(states, pio, pos)

  refid = uuid1()
  new_cmd = %{refid: refid, cmd_dt: Timex.now()}
  cmds = [new_cmd | cmds]
  updates = [states: new_states, pending_cmds: cmds, dt_last_cmd: Timex.now()]

  # persist the switch to the database
  {:ok, updated_sw} = sw |> change(updates) |> insert_or_update

  cmd = SetSwitch.new_cmd(sw.device, new_states, refid)
  Client.publish_switch_cmd(SetSwitch.json(cmd))

  {updated_sw, refid}
end

# handle the situation where a friendly_name is not found
def set_state({_, _}, _pos), do: nil

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
  Logger.metadata(switch_friendly_name: friendly_name)

  get_by_friendly_name(friendly_name) |>
    device_name_and_pio() |>
    get_by_unique_name() |>
    state()
end

# handle the situation where a friendly_name is not found
def state(nil), do: nil

def state({%Switch{} = s, pio})
when is_binary(pio) do
  state({s, String.to_integer(pio, 16)})
end

def state({%Switch{} = s, pio}) do
  find_state_by_pio(s.states, pio)
end

# handle the case when the unique name or pio aren't known
def state({_, _}), do: nil

def update_states({unique_id, states})
when is_binary(unique_id) and is_list(states) do
  add_or_update(unique_id) |> update_states(states)
end

def update_states(nil, _states), do: nil
def update_states(%Switch{} = sw, states) do
  update = [states: states]
  {:ok, updated} = sw |> change(update) |> insert_or_update
  updated
end

##
## HELPERS
##

defp get_friendly_names(%Switch{states: states} = s) do
  get_friendly_names(s, states)
end

defp get_friendly_names(%Switch{}, []), do: []
defp get_friendly_names(%Switch{} = s, states)
when is_list(states) do
  [get_friendly_names(s, hd(states)) | get_friendly_names(s, tl(states))]
end

defp get_friendly_names(%Switch{}, %{}), do: []
defp get_friendly_names(%Switch{} = s, %{"pio" => pio, "state" => _}) do
  device_name = ~s/#{s.device}:#{pio}/
  DevAlias.friendly_name(device_name)
end

# this is the workhorse for retrieving a pio state
# using recursion we search through the array of pio states
# looking for the matching pio
# Two outcomes are possible:
#  1. the pio is found and the actual state is returned
#  2. the pio is not found and nil is returned
defp find_state_by_pio(states, pio)
when is_list(states) and is_integer(pio) do
  case find_state_by_pio(hd(states), pio) do
    nil   -> find_state_by_pio(tl(states), pio)
    true  -> true     # the ACTUAL state of this Switch and pio
    false -> false
  end
end

# need to use strings as keys since that is how the map comes back from the
# database
defp find_state_by_pio(%{"pio" => pio, "state" => state}, requested_pio)
when pio == requested_pio do
  state
end

# if the above internal_state() didn't match then return nil to break out
# of the recursion
defp find_state_by_pio(%{"pio" => _pio, "state" => _state}, _requested_pio) do
  # Logger.info("pio=#{pio} state=#{state} requested_pio=#{requested_pio}")
  nil
end

defp update_pio_state(states, pio, pos)
when is_list(states) and is_integer(pio) and is_boolean(pos) do
  new_state = %{"pio" => pio, "state" => pos}
  index = Enum.find_index(states, fn(s) -> Map.get(s, "pio") == pio end)

  List.replace_at(states, index, new_state)
end

# Retrieving an actual Switch and associated pio for a friendly name is
# divided across multiple functions to enable use of the pipe operator
#
# 1. Using friendly name retrieve the DevAlias
# 2. From the DevAlias parse the device name into the unique name and pio
# 3. From the unique name retrieve the actual Switch
# 4. Return the actual Switch and associated pio to the caller as a tuple

# get the DevAlias for a friendly name
defp get_by_friendly_name(friendly_name)
when is_binary(friendly_name) do
  DevAlias.get_by_friendly_name(friendly_name)
end

defp device_name_and_pio(:nil), do: nil
defp device_name_and_pio(%DevAlias{} = dev) do
  [unique_id, pio] = String.split(dev.device, ":", parts: 2)
  {unique_id, String.to_integer(pio, 16)}
end

defp get_by_unique_name(unique_id)
when is_binary(unique_id) do
  get_by(Switch, [device: unique_id])
end

defp get_by_unique_name({unique_id, pio})
when is_binary(unique_id) and is_integer(pio) do
  {get_by_unique_name(unique_id), pio}
end

defp get_by_unique_name({_, _}), do: get_by_unique_name(nil)
defp get_by_unique_name(nil) do
  Logger.warn fn -> name = Logger.metadata() |>
                             Keyword.get(:switch_friendly_name)
                    ~s/friendly_name='#{name}' does not exist/ end
  nil
end

defp as_ms(ms)
when is_integer(ms) and ms < 1000 do
  "#{ms}ms"
end

defp as_ms(ms)
when is_integer(ms) and ms >= 1000 do
  val = ms / 1000 |> Float.round(2)
  "#{val}ms"
end

defp config(key)
when is_atom(key) do
  get_env(:mcp, Mcp.Switch) |> Keyword.get(key)
end

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

end
