defmodule SwitchCmd do
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
import Ecto.Query, only: [from: 2]
import Repo, only: [all: 2, one: 1, query: 1, preload: 2,
                    insert!: 1, update: 1, update_all: 2]

import Mqtt.Client, only: [publish_switch_cmd: 1]

alias Command.SetSwitch
alias Fact.RunMetric

schema "switch_cmd" do
  field :refid, :string
  field :name, :string
  field :acked, :boolean
  field :orphan, :boolean
  field :rt_latency, :integer
  field :sent_at, Timex.Ecto.DateTime
  field :ack_at, Timex.Ecto.DateTime
  belongs_to :switch, Switch

  timestamps usec: true
end

def ack_if_needed(%{cmdack: false}), do: :ok
def ack_if_needed(%{cmdack: true,
          refid: refid,
          msg_recv_dt: recv_dt}) when is_binary(refid) do

  cmd =
    from(cmd in SwitchCmd,
      where: cmd.refid == ^refid,
      preload: [:switch]) |> one()

  case cmd do
    nil  -> Logger.warn fn ->
              "cmd for refid [#{refid}] not found, won't ack" end

            {:not_found, refid}
    cmd  -> rt_latency = Timex.diff(recv_dt, cmd.sent_at)

            Logger.info fn ->
              "state name [#{cmd.name}] acking refid [#{refid}]" end

            opts = %{acked: true,
                     rt_latency: rt_latency,
                     ack_at: Timex.now()}

            RunMetric.record(module: "#{__MODULE__}",
                             metric: "rt_latency",
                             device: cmd.name,
                             val: opts.rt_latency)

            change(cmd, opts) |> update
  end
end

def ack_orphans(opts) do
  minutes_ago = opts.older_than_mins

  before = Timex.to_datetime(Timex.now(), "UTC") |>
              Timex.shift(minutes: (minutes_ago * -1))
  ack_at = Timex.now()

  from(sc in SwitchCmd,
        update: [set: [acked: true,
                       ack_at: ^ack_at,
                       orphan: true]],
        where: sc.acked == false,
        where: sc.sent_at < ^before) |> update_all([])
end

def unacked do
  from(cmd in SwitchCmd,
    join: sw in assoc(cmd, :switch),
    join: states in assoc(sw, :states), where: cmd.name == states.name,
    where: cmd.acked == false,
    preload: [switch: :states]) |> all(timeout: 100)
end

def unacked_count, do: unacked_count([])
def unacked_count(opts)
when is_list(opts) do
  minutes_ago = Keyword.get(opts, :minutes_ago, 0)

  earlier = Timex.to_datetime(Timex.now(), "UTC") |>
              Timex.shift(minutes: (minutes_ago * -1))

  from(c in SwitchCmd,
    where: c.acked == false,
    where: c.sent_at < ^earlier,
    select: count(c.id)) |> one()
end

def purge_acked_cmds(opts)
when is_map(opts) do

  hrs_ago = opts.older_than_hrs

  sql = ~s/delete from switch_cmd
              where acked = true and ack_at <
              now() at time zone 'utc' - interval '#{hrs_ago} hour'/

  query(sql) |> check_purge_acked_cmds()
end

def record_cmd(name, [%SwitchState{} = ss_ref | _tail] = list) do
  ss_ref = preload(ss_ref, :switch)  # ensure the associated switch is loaded
  sw = ss_ref.switch
  device = sw.device

  # create and presist a new switch comamnd
  scmd =
    Ecto.build_assoc(sw, :cmds,
                      refid: uuid1(),
                      name: name,
                      sent_at: Timex.now()) |> insert!()

  # update the last command datetime on the associated switch
  change(sw, dt_last_cmd: Timex.now()) |> update()

  # create and publish the actual command to the remote device
  new_state = SwitchState.as_list_of_maps(list)
  remote_cmd = SetSwitch.new_cmd(device, new_state, scmd.refid)
  publish_switch_cmd(SetSwitch.json(remote_cmd))
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
