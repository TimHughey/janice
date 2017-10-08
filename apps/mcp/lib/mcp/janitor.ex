defmodule Mcp.Janitor do
@moduledoc """
"""
require Logger
use GenServer
import Application, only: [get_env: 2]
import Process, only: [send_after: 3]

import Mcp.SwitchCmd, only: [purge_acked_cmds: 1]
alias Fact.RunMetric

def start_link(s) do
  GenServer.start_link(Mcp.Janitor, s,
                        name: Mcp.Janitor)
end

## Callbacks

def init(s)
when is_map(s) do
  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, config(:startup_delay_ms))
    false -> nil
  end

  Logger.info("init()")

  {:ok, s}
end

#
## GenServer callbacks
#

def handle_info({:startup}, s)
when is_map(s) do
  send_after(self(), {:purge_switch_cmds}, 0)

  {:noreply, s}
end

def handle_info({:purge_switch_cmds}, s)
when is_map(s) do
  hrs = purge_sw_cmds_older_than()

  purged = purge_acked_cmds(hours: hrs)

  RunMetric.record(module: "#{__MODULE__}",
    metric: "purged_sw_cmd_ack", val: purged)

  Logger.debug fn -> ~s/purged #{purged} acked switch commands/ end

  send_after(self(), {:purge_switch_cmds}, purge_sw_cmds_interval())

  {:noreply, s}
end

#
## Private functions
#

defp purge_sw_cmds_interval do
  config(:purge_switch_cmds_interval_minutes) * 60 * 1000
end

defp purge_sw_cmds_older_than do
  config(:purge_switch_cmds_older_than_hours) * -1
end

defp config(key)
when is_atom(key) do
  get_env(:mcp, Mcp.Janitor) |> Keyword.get(key)
end

end
