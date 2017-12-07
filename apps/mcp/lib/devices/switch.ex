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
import UUID, only: [uuid1: 0]
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]
import Mcp.Repo, only: [all: 2, update!: 1, one: 1, insert!: 1,
                        transaction: 1, preload: 2]

alias Fact.RunMetric
alias Mcp.DevAlias
alias Mcp.Switch
alias Mcp.SwitchState
alias Mcp.SwitchCmd

schema "switch" do
  field :device, :string
  field :enabled, :boolean, default: true
  field :dev_latency, :integer, default: nil
  field :discovered_at, Timex.Ecto.DateTime
  field :last_cmd_at, Timex.Ecto.DateTime
  field :last_seen_at, Timex.Ecto.DateTime
  has_many :states, Mcp.SwitchState
  has_many :cmds, Mcp.SwitchCmd

  timestamps usec: true
end

def all do
  all(Switch, timeout: 100) |> preload([:states])
end

def all(:friendly_names) do
  all_aliases = DevAlias.all()

  only_switches =
    Enum.filter(all_aliases,
      fn(item) -> is_switch?(item.friendly_name) end)

  Enum.map(only_switches,
      fn(item) -> item.friendly_name end)
end

def external_update(r)
when is_map(r) do
  Logger.metadata(switch_device: r.device)

  {t, {:ok, fnames}} =
    :timer.tc fn ->
        transaction fn ->
        # pipeline to handle whatever update we receive
        # each function in the pipeline will determined what (if anything)
        # must be done
        sw = get_by_device_name(r.device, r.pio_count) |>
              update_switch(r, :external) |> acknowledge_cmd(r)

        # always get every fname to ensure they exist (or are created)
        get_fnames(sw) end
      end

  RunMetric.record(module: "#{__MODULE__}",
    metric: "external_update", device: r.device, val: t)

  fnames
end

def get(:friendly_name, fname)
when is_binary(fname) do
  %{device: dev} = fname_to_dev(fname) |> device_name_and_pio()
  get_by_device_name(dev)
end

@doc ~S"""
Get the state of a switch by friendly name

## Examples:
  iex> state = Mcp.Switch.get_state("led1")
  iex> is_boolean(state)
  true

  iex> Mcp.Switch.get_state("foobar")
  nil
"""
def get_state(fname)
when is_binary(fname) do
  {t, state} =
    :timer.tc fn ->
      fname_to_dev(fname) |> device_name_and_pio() |> get_state() end

  RunMetric.record(module: "#{__MODULE__}",
    metric: "get_state", val: t)

  state
end

def get_state(%{device: device, pio: pio}) do
  %Switch{states: states} = get_by_device_name(device)
  find_state_by_pio(states, pio) |> get_state()
end

def get_state(%SwitchState{state: state}), do: state
def get_state(_dev), do: nil

def get_unack_cmds(fname)
when is_binary(fname) do
  {t, cmds} =
    :timer.tc fn ->
      fname_to_dev(fname) |> device_name_and_pio() |> get_unack_cmds() end

  RunMetric.record(module: "#{__MODULE__}",
    metric: "get_state", val: t)

  cmds
end

def get_unack_cmds(%{device: device, pio: _pio}) do
  query =
    from(sw in Switch,
      join: cmd in assoc(sw, :cmds),
      join: state in assoc(sw, :states),
      where: sw.device == ^device and cmd.acked == false,
      preload: [cmds: cmd, states: state])

  one(query) |> get_unack_cmds()
end

def get_unack_cmds(%Switch{cmds: cmds}), do: cmds
def get_unack_cmds(nil), do: []

def set_state(fname, state)
when is_binary(fname) and is_boolean(state) do
  {t, {:ok, sw}} =
    :timer.tc fn ->
      transaction fn ->
        fname_to_dev(fname) |> device_name_and_pio() |>
          set_state(state, :internal) end
    end

  RunMetric.record(module: "#{__MODULE__}",
    metric: "set_state", val: t)

  sw
end

def is_switch?(nil), do: false
def is_switch?(fname)
when is_binary(fname) do
  DevAlias.get_by_friendly_name(fname) |> is_switch?()
end

def is_switch?(%DevAlias{} = dev) do
  device_name_and_pio(dev) |> is_switch?()
end

def is_switch?(%{device: device, pio: _pio}) do
  from(sw in Switch, where: sw.device == ^device) |>
    one() |> is_switch?()
end

def is_switch?(%Switch{}), do: true

def set_state(%{device: device, pio: pio}, state, src)
when is_boolean(state) and is_atom(src) do
  # assemble a minimal map of the update so we can leverage the
  # update_switch code (originally developed for external updates)
  r = %{states: [%{pio: pio, state: state}], latency: 0}
  get_by_device_name(device) |> update_switch(r, src)
end
def set_state(_dev, _pos, _src), do: []

##
## Internal / private functions
##

# if this is not a cmdack then just return the switch
# allows this function to be called cleanly in a pipeline
defp acknowledge_cmd(%Switch{} = sw, %{cmdack: false}), do: sw

defp acknowledge_cmd(%Switch{device: device},
                      %{refid: refid, cmdack: true} = r) do
  Logger.metadata(switch_ack_refid: refid)

  query =
    from(sw in Switch,
    join: cmd in assoc(sw, :cmds),
    join: state in assoc(sw, :states),
    where: sw.device == ^device and
            cmd.refid == ^refid and cmd.acked == false,
    preload: [cmds: cmd, states: state])

  one(query) |> acknowledge_individual_cmd(r)
end

defp acknowledge_individual_cmd(%Switch{cmds: [cmd]} = sw,
                                  %{latency: latency,
                                    msg_recv_dt: msg_recv_dt}) do

  rt_latency = Timex.diff(msg_recv_dt, cmd.sent_at)

  opts = [acked: true, dev_latency: latency,
            rt_latency: rt_latency, ack_at: Timex.now()]

  change(cmd, opts) |> update!()

  RunMetric.record(module: "#{__MODULE__}",
    metric: "rt_latency", device: sw.device, val: rt_latency)

  RunMetric.record(module: "#{__MODULE__}",
    metric: "dev_latency", device: sw.device, val: latency)

  opts = [dev_latency: latency, last_cmd_at: Timex.now()]

  change(sw, opts) |> update!()  # update the actual sw and return it
end

# handle the case where there aren't commands to ack
defp acknowledge_individual_cmd(%Switch{cmds: []} = sw, _r) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    refid = Logger.metadata() |> Keyword.get(:switch_ack_refid)
    ~s/cmd_ack found fname=#{fname} device=#{device} refid=#{refid}/ end

  sw # always return the switch passed
end

# create a DateTime that is before now
# used when creating a new switch
defp before_now do
  dt = Timex.to_datetime(Timex.now(), "UTC")
  Timex.shift(dt, hours: -3)
end

defp compound_device_name(_device, []), do: []

defp compound_device_name(device, ss)
when is_list(ss) do
  [compound_device_name(device, hd(ss))] ++
    compound_device_name(device, tl(ss))
end

defp compound_device_name(device, %SwitchState{pio: pio}) do
  ~s/#{device}:#{pio}/
end

# if a Switch was not found (indicated by :nil) then create one
# and the associated switch states and a faux switch command
# NOTE: if pio_count is 0 then DO NOT create a switch if not found
defp create_if_does_not_exist(:nil, device, pio_count)
when is_binary(device) and pio_count > 0 do
  # create a list of states (with default states)
  states = create_states(pio_count)

  # let's create a faux switch cmd and immediately ack it so there's
  # at least one cmd.  this helps with later code so there is at least
  # one cmd (less checks)
  cmds = [%SwitchCmd{refid: uuid1(), acked: true, ack_at: before_now()}]

  sw = %Switch{device: device, cmds: cmds, states: states}

  insert!(sw)
end

# if the switch was found or pio_count < 1 then just return whatever
# was originally passed (could be a Switch or nil)
defp create_if_does_not_exist(pass, _device, _pio_count), do: pass

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

defp device_name_and_pio(nil) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    ~s/could not find switch fname=#{fname} device=#{device}/ end

  nil
end

defp device_name_and_pio(%DevAlias{device: device} = dev) do
  device_name_and_pio(dev, String.contains?(device, ":"))
end

# parse a compound device name (unique_id and pio) into it's parts
defp device_name_and_pio(%DevAlias{} = dev, true) do
  [unique_id, pio] = String.split(dev.device, ":", parts: 2)

  %{device: unique_id, pio: String.to_integer(pio, 16)}
end

defp device_name_and_pio(%DevAlias{}, false), do: nil

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

# lookup up the device alias for a fname
defp fname_to_dev(fname)
when is_binary(fname) do
  dev = DevAlias.get_by_friendly_name(fname)

  # save references to what is being attemtped in case there is an
  # error (or something isn't found)
  Logger.metadata(switch_fname: fname)
  if not is_nil(dev) do
    Logger.metadata(switch_device: dev.device)
  else
    Logger.metadata(switch_device: "[not found]")
  end

  dev
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

# here we break out of the recursion and we return an empty list because when
# it is ++ to the accumulator it will be ignored
defp get_fnames(_device, []), do: []

# create the compound device name, get (and return) the friendly name
defp get_fname(device, %SwitchState{} = ss) do
  compound_device_name(device, ss) |>
    DevAlias.friendly_name()
end

# this is the entry point as it accepts a list of states
# first we find the state then we update it
defp update_pio_state(states, pio, pos)
when is_list(states) and is_integer(pio) and is_boolean(pos) do
  [find_state_by_pio(states, pio) |> update_pio_state(pio, pos)]
end

# if we have an actual SwitchState then update in the database
# but only if the new state) is different than existing
# additionally, add a switch command for this update
defp update_pio_state(%SwitchState{state: state} = ss, pio, new_state)
when is_integer(pio) and state != new_state do
  #change(ss, state: new_state) |> update!() |> SwitchCmd.record_cmd()
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
    ~s/pio=#{pio} does not exist for fname=#{fname} device=#{device}/
  end

  []  # return an empty list since it's quietly concatenated into nothing!
end

# update all the switch states based on a map of data
defp update_switch(%Switch{device: device, states: ss} = sw, r, src)
when is_map(r) and is_atom(src) do
  new_ss = update_switch_states(ss, r.states)

  case src do
    :external -> nil # when the updates are from the remote, don't send back
    :internal -> SwitchCmd.record_cmd(new_ss) # if update is local, then send
  end

  compound_device_name(device, new_ss) |>
    DevAlias.just_seen()

  change(sw, last_seen_at: Timex.now()) |>
    update!()
end

# handle the situation where we get a nil (no switch)
# usually happens in a pipeline
defp update_switch(nil, _r, _) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    ~s/unknown switch fname=#{fname} device=#{device}/
  end
  [] # empty list
end

# here we get out of the recursion by detecting the end of the
# new_state list
defp update_switch_states([%SwitchState{} | _], []), do: []

# update the switch state with the head of the list of new states
# then recurse through the remainder of the list
defp update_switch_states([%SwitchState{} | _] = states,
                          [%{pio: pio, state: state} | rest_ns]) do
  update_pio_state(states, pio, state) ++ update_switch_states(states, rest_ns)
end

defp update_switch_states([%SwitchState{} | _], [%{} | _rest_ns]) do
  Logger.warn fn ->
    fname = Logger.metadata() |> Keyword.get(:switch_fname)
    device = Logger.metadata() |> Keyword.get(:switch_device)
    ~s/empty map detected in states fname=#{fname} device=#{device}/ end
end
end
