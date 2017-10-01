defmodule Mcp.Switches do
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

def before_now do
  dt = Timex.to_datetime(Timex.now(), "UTC")
  Timex.shift(dt, hours: -3)
end

schema "switches" do
  field :friendly_name, :string
  field :disabled, :boolean, default: false
  field :pio, :boolean, default: false
  field :num_pio, :integer, default: 0
  field :pios, :map, default: %{}
  field :pending_cmds, {:array, :map}, default: []
  field :dt_last_cmd, Timex.Ecto.DateTime
  field :dt_discovered, Timex.Ecto.DateTime

  timestamps usec: true
end

@doc ~S"""
Retrieve a switch (which only have friendly names)

## Examples:
  iex> s = Mcp.Switches.get("water_pump")
  ...> %{friendly_name: friendly_name} = s
  ...> friendly_name
  "water_pump"

  iex> Mcp.Switches.get("unknown")
  nil
"""
def get(friendly_name) when is_binary(friendly_name) do
  case get_by(Switches, [friendly_name: friendly_name]) do
    nil -> nil
    s -> s
  end
end

@doc ~S"""
Set the pio (on / off) of a Switch

## Examples:
  iex> pio = true
  ...> m = Mcp.Switches.set_pio(pio, "water_pump")
  ...> %{cmd_ref: cmd_ref, pio: new_pio} = m
  ...> {String.valid?(cmd_ref.uuid),
  ...>    Timex.is_valid?(cmd_ref.cmd_dt),
  ...>    pio === new_pio}
  {true, true, true}
"""
def set_pio(pio, friendly_name)
when is_boolean(pio) and is_binary(friendly_name) do

  s = get(friendly_name)
  %{pending_cmds: cmds} = s

  uuid = uuid1()
  ts = Timex.now()
  new_cmd = %{uuid: uuid, cmd_dt: ts}
  cmds = [new_cmd | cmds]
  updates = [pio: pio, pending_cmds: cmds, dt_last_cmd: Timex.now()]

  {:ok, updated} = s |> change(updates) |> insert_or_update
  [cmd_ref | _] = updated.pending_cmds
  %{cmd_ref: cmd_ref, pio: pio}
end

@doc ~S"""
Turn off a Switch

## Examples:
  iex> m = Mcp.Switches.off("water_pump")
  ...> %{cmd_ref: cmd_ref, pio: new_pio} = m
  ...> {String.valid?(cmd_ref.uuid), Timex.is_valid?(cmd_ref.cmd_dt), new_pio}
  {true, true, false}
"""
def off(friendly_name)
when is_binary(friendly_name) do
  set_pio(false, friendly_name)
end

@doc ~S"""
Turn on a Switch

## Examples:
  iex> Mcp.Switches.on("water_pump")
  true
"""
def on(friendly_name)
when is_binary(friendly_name) do
  updated = set_pio(true, friendly_name)
  updated.pio
end

@doc ~S"""
Retrieve the time a Switch was discovered

## Examples:
  iex> Mcp.Switches.discovered("water_pump") |> Timex.is_valid?
  true

  iex> Mcp.Switches.discovered("unknown")
  nil
"""
def discovered(friendly_name) when is_binary(friendly_name) do
  case get_by(Switches, [friendly_name: friendly_name]) do
    nil -> nil
    s -> s.dt_discovered
  end
end

@doc ~S"""
Add a new Switch

## Examples:
  iex> s = %Mcp.Switches{friendly_name: "heater"}
  ...> %{friendly_name: friendly_name} = Mcp.Switches.add(s)
  ...> friendly_name
  "heater"
"""
def add(%Switches{} = s) do
  to_add =
    case get_by(Switches, friendly_name: s.friendly_name) do
      nil -> s
      friendly_name -> friendly_name
    end

  update = [dt_discovered: Timex.now()]

  {:ok, added} = to_add |> change(update) |> insert_or_update
  added
end

@doc ~S"""
Acknowledge a Switch command

"""
def ack_cmd(friendly_name, uuid)
when is_binary(friendly_name) and is_binary(uuid) do
  s = get(friendly_name)

  compare_uuid = fn cmd -> Map.get(cmd, "uuid") == uuid end

  index = Enum.find_index(s.pending_cmds, compare_uuid)
  ack_cmd_at_index(s, index)
end

defp ack_cmd_at_index(%Switches{}, index) when is_nil(index) do
  {:nil, 0}
end

defp ack_cmd_at_index(%Switches{} = s, index) when is_integer(index) do
  {cmd_to_ack, pending_cmds} = List.pop_at(s.pending_cmds, index)

  updates = [pending_cmds: pending_cmds]
  {:ok, _} = s |> change(updates) |> insert_or_update

  acked_cmd_dt = Map.get(cmd_to_ack, "cmd_dt")
  acked_uuid = Map.get(cmd_to_ack, "uuid")

  latency = Timex.diff(Timex.now(), acked_cmd_dt)
  {acked_uuid, latency}
end

@doc ~S"""
Purge all pending commands from a Switch

## Examples:
  iex> Mcp.Switches.purge_all_pending_cmds("water_pump")
  :ok
"""
def purge_all_pending_cmds(friendly_name) when is_binary(friendly_name) do
  s = get(friendly_name)

  updates = [pending_cmds: []]

  {:ok, _} = s |> change(updates) |> insert_or_update
  :ok
end

end
