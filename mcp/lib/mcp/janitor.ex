defmodule Janitor do
@moduledoc """
"""
require Logger
use GenServer
import Application, only: [get_env: 3]
import Process, only: [send_after: 3]

import Mcp.SwitchCmd, only: [purge_acked_cmds: 1]
alias Fact.RunMetric

def start_link(s) do
  defs = [purge_switch_cmds: [interval_mins: 2, older_than_hrs: 2, log: false]]
  opts = get_env(:mcp, Janitor, defs)

  s = Map.put(s, :purge_switch_cmds, Keyword.get(opts, :purge_switch_cmds))

  GenServer.start_link(Janitor, s, name: Janitor)
end

## Callbacks

def init(s)
when is_map(s) do
  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, 0)
    false -> nil
  end

  Logger.info("init()")

  {:ok, s}
end

@log_purge_cmds_msg :log_purge_cmds_msg
def log_purge_cmds(val)
when is_boolean(val) do
  GenServer.call(Janitor, {@log_purge_cmds_msg, val})
end

#
## GenServer callbacks
#

def handle_call({@log_purge_cmds_msg, val}, _from, s) do
  s = Map.put(s, :purge_switch_cmds,
                Keyword.put(s.purge_switch_cmds, :log, val))

  {:reply, :ok, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  send_after(self(), {:purge_switch_cmds}, 0)

  Logger.info("startup()")

  {:noreply, s}
end

def handle_info({:purge_switch_cmds}, s)
when is_map(s) do
  hrs = purge_sw_cmds_older_than()

  purged = purge_acked_cmds(hours: hrs)

  RunMetric.record(module: "#{__MODULE__}",
    metric: "purged_sw_cmd_ack", val: purged)

  log_purge(s) && Logger.info fn ->
    ~s/purged #{purged} acked switch commands/ end

  send_after(self(), {:purge_switch_cmds}, purge_sw_cmds_interval())

  {:noreply, s}
end

#
## Private functions
#

defp purge_sw_cmds_interval do
  (get_env(:mcp, Janitor, []) |>
    Keyword.get(:purge_switch_cmds, []) |>
    Keyword.get(:interval_mins, 2)) * 60 * 1000
end

defp purge_sw_cmds_older_than do
  (get_env(:mcp, Janitor, []) |>
    Keyword.get(:purge_switch_cmds, []) |>
    Keyword.get(:older_than_hrs, 2)) * -1
end

defp log_purge(s) do
  Keyword.get(s.purge_switch_cmds, :log)
end

end
