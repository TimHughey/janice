defmodule Mcp.SwitchCmd do
@moduledoc """
  The SwithCommand module provides the database schema for tracking
  commands sent for a Switch.
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

# import Application, only: [get_env: 2]
import UUID, only: [uuid1: 0]
import Ecto.Changeset, only: [change: 2]
import Mcp.Repo, only: [query: 1, preload: 2, insert!: 1, update!: 1]

import Mqtt.Client, only: [publish_switch_cmd: 1]

alias Command.SetSwitch
alias Mcp.SwitchState

schema "switch_cmd" do
  field :refid, :string
  field :acked, :boolean
  field :dev_latency, :float
  field :rt_latency, :float
  field :dt_sent, Timex.Ecto.DateTime
  field :dt_ack, Timex.Ecto.DateTime
  belongs_to :switch, Mcp.Switch

  timestamps usec: true
end

def purge_acked_cmds do
  hrs_ago = -3
  purge_acked_cmds([hours: hrs_ago])
end

def purge_acked_cmds([hours: hrs_ago])
when hrs_ago < 0 do

  sql = ~s/delete from switch_cmd
              where dt_ack <
              now() at time zone 'utc' - interval '#{hrs_ago} hour'/

  query(sql) |> check_purge_acked_cmds()
end

def record_cmd([%SwitchState{} = ss_ref | _tail] = list) do
  ss_ref = preload(ss_ref, :switch)  # ensure the associated switch is loaded
  sw = ss_ref.switch
  device = sw.device

  # create and presist a new switch comamnd
  scmd =
    Ecto.build_assoc(sw, :cmds,
                      refid: uuid1(),
                      dt_sent: Timex.now()) |> insert!()

  # update the last command datetime on the associated switch
  change(sw, dt_last_cmd: Timex.now()) |> update!()

  # create and publish the actual command to the remote device
  new_state = SwitchState.as_list_of_maps(list)
  remote_cmd = SetSwitch.new_cmd(device, new_state, scmd.refid)
  publish_switch_cmd(SetSwitch.json(remote_cmd))

  list # return the switch states passed in
end
#
# Private functions
#

defp check_purge_acked_cmds({:error, e}) do
  Logger.warn fn ->
    ~s/failed to purge acked cmds msg='#{Exception.message(e)}'/ end
  0
end

defp check_purge_acked_cmds({:ok, %{command: :delete, num_rows: nr}}), do: nr

end
