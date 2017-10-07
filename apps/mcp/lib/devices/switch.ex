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

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

# import Application, only: [get_env: 2]
import UUID, only: [uuid1: 0, uuid4: 0]
import Ecto.Changeset, only: [change: 2]

import Ecto.Query, only: [from: 2]
import Mcp.Repo, only: [get_by: 2, update!: 1, one: 1, insert!: 1,
                        transaction: 1]

#import Mqtt.Client, only: [publish_switch_cmd: 1]

alias Command.SetSwitch
alias Mcp.DevAlias
alias Mcp.Switch
alias Mcp.SwitchState
alias Mcp.SwitchCmd
alias Mqtt.Client

def before_now do
  dt = Timex.to_datetime(Timex.now(), "UTC")
  Timex.shift(dt, hours: -3)
end

schema "switch" do
  field :device, :string
  field :enabled, :boolean, default: true
  field :dev_latency, :float, default: nil
  field :dt_last_cmd, Timex.Ecto.DateTime
  field :dt_discovered, Timex.Ecto.DateTime
  field :dt_last_seen, Timex.Ecto.DateTime
  has_many :states, Mcp.SwitchState
  has_many :cmds, Mcp.SwitchCmd

  timestamps usec: true
end

def external_update(r)
when is_map(r) do
  Logger.metadata(switch_device: r.device)
  transaction fn ->
    sw = get_by_device_name(r.device, r.pio_count) |> update_switch(r)
    get_fnames(sw) end
end

def set_state(_dev, _pos), do: []
##
## HELPERS
##

# we a Switch was not found (indicated by :nil) then create one
# and the associated switch states and a faux switch command
defp create_if_does_not_exist(:nil, device, pio_count)
when is_binary(device) and is_integer(pio_count) do
  # create a list of states (with default states)
  states = create_states(pio_count)

  # let's create a faux switch cmd and immediately ack it so there's
  # at least one cmd.  this helps with later code so there is at least
  # one cmd (less checks)
  cmds = [%SwitchCmd{refid: uuid1(), acked: true, dt_ack: before_now()}]

  sw = %Switch{device: device, cmds: cmds, states: states}

  insert!(sw)
end

# if the switch was found then just return it
defp create_if_does_not_exist(%Switch{} = sw, _device, _pio_count), do: sw

defp create_states(pio_count) # primary entry point for create states
when is_integer(pio_count) do
  create_states([], pio_count - 1)
end

defp create_states(acc, pio_count)         # actually create the state
when is_list(acc) and pio_count >= 0 do     # and add to the acc then recurse
  acc = acc ++ [%SwitchState{pio: pio_count}]
  create_states(acc, pio_count - 1)
end

defp create_states(acc, requested_pio)
when requested_pio < 0, do: acc  # all states created

# parse a compound device name (unique_id and pio) into it's parts
defp device_name_and_pio(%DevAlias{} = dev) do
  [unique_id, pio] = String.split(dev.device, ":", parts: 2)

  %{device: unique_id, pio: String.to_integer(pio, 16)}
end

defp device_name_and_pio(:nil), do: nil

# look at the first state in the list of states and if matches the
# requested pio then return it -- search complete
defp find_state_by_pio([%SwitchState{pio: pio} = ss | _rest], requested_pio)
when pio == requested_pio do
  ss
end

# if the first state in the list DOES NOT match the requested pio then
# recurse through the remaining states
defp find_state_by_pio([%SwitchState{pio: pio} | rest], requested_pio)
when pio != requested_pio do
  find_state_by_pio(rest, requested_pio)
end

# if we get an empty list we've reached the end of the list of states
# without finding the requested pio (or we were passed an empty state)
# either should be result in a warning
defp find_state_by_pio([], pio) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    ~s/reached end of states pio=#{pio} fname=#{fname} device=#{device}/
  end

  :nil
end

# retrieve a device from the database
# pio_count is only used to create a new switch when the device doesn't exist
# NOTE: ew only preload the switch states from the associations
#       since they are likely relevant for whatever is done next
defp get_by_device_name(device, pio_count \\ 0) do
  query =
    from(sw in Switch,
      join: states in assoc(sw, :states),
      #join: cmds in assoc(sw, :cmds),
      #where: sw.device == ^device and cmds.acked == false,
      where: sw.device == ^device,
      preload: [states: states])

  one(query) |> create_if_does_not_exist(device, pio_count)
end

# the primary entry point for getting fnames from a list of states
defp get_fnames(%Switch{device: device, states: ss}) do
  # create a list of friendly names then recurse through the rest of the list
  get_fnames(device, ss)
end

# if we get a nil then just return an empty list, seems to make sense
defp get_fnames(:nil), do: []

defp get_fnames(device, [%SwitchState{} = ss | ss_rest]) do
  [get_fname(device, ss)] ++ get_fnames(device, ss_rest)
end

# create the compound device name, get (and return) the friendly name
defp get_fname(device, %SwitchState{pio: pio}) do
  device_name = ~s/#{device}:#{pio}/
  DevAlias.friendly_name(device_name)
end

# here we break out of the recursion and we return an empty list because when
# it is ++ to the accumulator it will be ignored
defp get_fnames(_device, []), do: []

# this is the entry point as it accepts a list of states
# first we find the state then we update it
defp update_pio_states(states, pio, pos)
when is_list(states) and is_integer(pio) and is_boolean(pos) do
  find_state_by_pio(states, pio) |> update_pio_state(pio, pos)
end

# if we have an actual SwitchState then update in the database
# but only if the new state) is different than existing
defp update_pio_state(%SwitchState{state: state} = ss, pio, new_state)
when is_integer(pio) and state != new_state do
  change(ss, state: new_state) |> update!()
end

# nop if the existing state equals the new_state
defp update_pio_state(%SwitchState{state: state} = ss, pio, new_state)
when is_integer(pio) and state == new_state, do: ss

# ok... didn't find the SwitchState to update so log a warning
defp update_pio_state(:nil, pio, _pos) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    ~s/pio=#{pio} not found for fname=#{fname} device=#{device}/
  end

  []  # return an empty list since it's quietly concatenated into nothing!
end

# update all the switch states based on a map of data
defp update_switch(%Switch{states: ss} = sw, r)
when is_map(r) do
  _new_ss = update_switch_states(ss, r.states)

  dev_latency = (r.latency / 1000) |> Float.round(2)

  change(sw, dev_latency: dev_latency, dt_last_seen: Timex.now()) |>
    update!()
end

# update the switch state with the head of the list of new states
# then recurse through the remainder of the list
defp update_switch_states(ss, [ns | rest_ns])
when is_map(ns) do
  [update_switch_states(ss, ns)] ++ update_switch_states(ss, rest_ns)
end

# do the actual pio update
defp update_switch_states(ss, %{pio: pio, state: state}) do
  update_pio_states(ss, pio, state)
end

# here we get out of the recursion by detecting the end of the
# new_state list
defp update_switch_states(_, _), do: []

# Retrieving an actual Switch and associated pio for a friendly name is
# divided across multiple functions to enable use of the pipe operator
#
# 1. Using friendly name retrieve the DevAlias
# 2. From the DevAlias parse the device name into the unique name and pio
# 3. From the unique name retrieve the actual Switch
# 4. Return the actual Switch and associated pio to the caller as a tuple

# get the DevAlias for a friendly name
# defp get_by_friendly_name(friendly_name)
# when is_binary(friendly_name) do
#   DevAlias.get_by_friendly_name(friendly_name)
# end

# defp get_by_unique_name(unique_id)
# when is_binary(unique_id) do
#   get_by(Switch, [device: unique_id])
# end
#
# defp get_by_unique_name({unique_id, pio})
# when is_binary(unique_id) and is_integer(pio) do
#   {get_by_unique_name(unique_id), pio}
# end
#
# defp get_by_unique_name({_, _}), do: get_by_unique_name(nil)
# defp get_by_unique_name(nil) do
#   Logger.warn fn -> name = Logger.metadata() |>
#                              Keyword.get(:switch_fname)
#                     ~s/friendly_name='#{name}' does not exist/ end
#   nil
# end

# defp as_ms(ms)
# when is_integer(ms) and ms < 1000 do
#   "#{ms}ms" |> String.pad_leading(10)
# end
#
# defp as_ms(ms)
# when is_integer(ms) and ms >= 1000 do
#   val = ms / 1000 |> Float.round(2)
#   "#{val}ms" |> String.pad_leading(10)
# end
#
# defp config(key)
# when is_atom(key) do
#   get_env(:mcp, Mcp.Switch) |> Keyword.get(key)
# end

# def acknowledge_cmd({unique_id, states, refid, latency})
# when is_binary(unique_id) and is_list(states) and is_binary(refid) and
# is_number(latency) do
#   acknowledge_cmd({unique_id, states, refid, latency}, :transaction)
# end
#
# def acknowledge_cmd({unique_id, states, refid, latency}, :transaction)
# when is_binary(unique_id) and is_list(states) and is_binary(refid) and
# is_number(latency) do
#   transaction fn ->
#     acknowledge_cmd({unique_id, states, refid, latency}, :no_transaction)
#   end
# end
#
# def acknowledge_cmd({unique_id, states, refid, latency}, :no_transaction)
# when is_binary(unique_id) and is_list(states) and is_binary(refid) and
# is_number(latency) do
#   ack_recv_dt = Timex.now()
#
#   Logger.metadata(switch_ack_refid: refid)
#
#   query =
#     from(s in Switch,
#       join: c in assoc(s, :cmds),
#       where: s.device == ^unique_id and c.refid == ^refid
#               and c.acked == false,
#       preload: [switch_cmd: c])
#
#   # TODO: should handle the case when no switch cmds exist
#   #       break this out into a separate function and use guards
#   sw = one(query)
#   cmdack = Map.get(sw, :cmds) |> hd  # :cmds is a list, get first
#
#   rt_latency =
#     (Timex.diff(ack_recv_dt, cmdack.dt_sent) / 1000) |> Float.round(2)
#
#   # latency from mcr is reported in microseconds, convert to millis
#   dev_latency = (latency / 1000) |> Float.round(2)
#
#   cmd_ack_updates = [acked: true, dev_latency: dev_latency,
#                      rt_latency: rt_latency, dt_ack: ack_recv_dt]
#   {:ok, cmdack} = cmdack |> change(cmd_ack_updates) |> insert_or_update
#
#   sw_updates = [states: states]
#   {:ok, updated} = sw |> change(sw_updates) |> insert_or_update
#
#   updated
# end

end
