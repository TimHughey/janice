defmodule Janitor do
@moduledoc """
"""
require Logger
use GenServer
import Application, only: [get_env: 3]
import Process, only: [send_after: 3]

alias Mcp.SwitchCmd
alias Fact.RunMetric

@purge_timer :purge_timer

def start_link(s) do
  defs = [purge_switch_cmds: [interval_mins: 1, older_than_hrs: 12, log: false]]
  opts = get_env(:mcp, Janitor, defs)

  s = Map.put(s, :purge_switch_cmds, Keyword.get(opts, :purge_switch_cmds))
  s = Map.put(s, @purge_timer, nil)

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

@manual_purge_msg :purge_switch_cmds
def manual_purge do
  GenServer.call(Janitor, {@manual_purge_msg})
end

@opts_msg :opts
def opts(new_opts \\ []) do
  GenServer.call(Janitor, {@opts_msg, new_opts})
end

#
## GenServer callbacks
#

# if an empty list this is a request for the current configred opts
def handle_call({@opts_msg, []}, _from, s) do
  {:reply, s.purge_switch_cmds, s}
end

# if there is a non-empty list then set the opts to the list
def handle_call({@opts_msg, new_opts}, _from, s)
when is_list(new_opts) do
  s = Map.put(s, :purge_switch_cmds,
                Keyword.merge(s.purge_switch_cmds, new_opts))

  # reschedule purge won't do anything if the interval is the same
  s = reschedule_purge(s, new_opts)

  {:reply, s.purge_switch_cmds, s}
end

def handle_call({@log_purge_cmds_msg, val}, _from, s) do
  s = Map.put(s, :purge_switch_cmds,
                Keyword.put(s.purge_switch_cmds, :log, val))

  {:reply, :ok, s}
end

def handle_call({@manual_purge_msg}, _from, s) do
  Logger.info fn -> "manual purge requested" end
  result = purge_sw_cmds(s)
  Logger.info fn -> "manually purged #{result} switch cmds" end

  {:reply, result, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  Logger.info("startup()")

  s = schedule_purge(s, 0)

  {:noreply, s}
end

def handle_info({:purge_switch_cmds}, s)
when is_map(s) do
  purge_sw_cmds(s)

  s = schedule_purge(s)

  {:noreply, s}
end

#
## Private functions
#

defp log_purge(s) do
  Keyword.get(s.purge_switch_cmds, :log)
end

defp purge_sw_cmds(s)
when is_map(s) do
  purged = SwitchCmd.purge_acked_cmds(s.purge_switch_cmds)

  RunMetric.record(module: "#{__MODULE__}",
    metric: "purged_sw_cmd_ack", val: purged)

  if log_purge(s) do
    (purged > 0) && Logger.info fn ->
      ~s/purged #{purged} acked switch commands/ end
  end

  purged
end

# handle the situation where the interval has been changed
defp reschedule_purge(s, new_opts)
when is_map(s) and is_list(new_opts) do
  asis = Keyword.get(s.purge_switch_cmds, :interval_mins)
  tobe = Keyword.get(new_opts, :interval_mins)

  if asis != tobe do
    Logger.info fn -> "rescheduling purge for interval #{tobe}" end
    reschedule_purge(s)
  else
    s
  end
end

defp reschedule_purge(s) do
  timer = Map.get(s, @purge_timer)
  unless(timer) do Process.cancel_timer(timer) end

  schedule_purge(s)
end

defp schedule_purge(s)
when is_map(s) do
  mins = s.purge_switch_cmds |> Keyword.get(:interval_mins, 2)
  after_millis = mins * 60 * 1000
  schedule_purge(s, after_millis)
end

defp schedule_purge(s, after_millis)
when is_map(s) do
  t = send_after(self(), {:purge_switch_cmds}, after_millis)
  Map.put(s, @purge_timer, t)
end

end
