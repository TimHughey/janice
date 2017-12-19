defmodule Command.Control do
@moduledoc """
"""
require Logger
use GenServer

import Application, only: [get_env: 2, get_env: 3]
import Process, only: [send_after: 3]
import Mqtt.Client, only: [publish: 1]

alias Command.Timesync

#
# GenServer Startup and Initialization
#
def start_link(s) do
  GenServer.start_link(Command.Control, s, name: Command.Control)
end

def init(s)
when is_map(s) do

  Logger.info fn -> "init()" end

  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, 0)
             # send_after(self(), {:timesync_cmd}, config(:startup_delay_ms) + 1)
    false -> nil
  end

  {:ok, s}
end

#
# External Functions
#
def send_timesync do
  feed = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, nil)

  if feed do
    msg = Timesync.new_cmd() |> Timesync.json()
    cmd = publish_opts(feed, msg)

    publish(cmd)
  else
    :cmd_feed_config_missing
  end
end

#
# GenServer Callbacks
#

def handle_info({:startup}, s)
when is_map(s) do
  s = start_timesync_task(s, config(:timesync_opts))

  {:noreply, s}
end

def handle_info({ref, result},
                  %{timesync: %{task: %{ref: timesync_ref}}} = s)
when is_reference(ref) and ref == timesync_ref do
  if result == :cmd_feed_config_missing do
    Logger.warn fn -> "timesync missing feed configuration" end
  end

  s = Map.put(s, :timesync, Map.put(s.timesync, :result, result))

  {:noreply, s}
end

def handle_info({:DOWN, ref, :process, pid, reason},
                  %{timesync: %{task: %{ref: timesync_ref}}} = s)
when is_reference(ref) and is_pid(pid) do

  s =
    if ref == timesync_ref do
      track =
        Map.put(s.timesync, :exit, reason) |> Map.put(:task, nil) |>
        Map.put(:status, :finished)

      Map.put(s, :timesync, track)
    end

  {:noreply, s}
end

defp start_timesync_task(s, opts)
when is_map(s) do

  track =
    %{task: Task.async(Timesync, :run, [opts]),
      status: :started}

  Map.put(s, :timesync, track)
end

def timesync_cmd_task(opts) do
  frequency = Keyword.get(opts, :frequency, 1000)
  loops = Keyword.get(opts, :loops, 1)
  forever = Keyword.get(opts, :forever, false)
  feed = Keyword.get(opts, :feed, false)
  log = Keyword.get(opts, :log, false)


  if feed do
    msg = Timesync.new_cmd() |> Timesync.json()
    cmd = publish_opts(feed, msg)

    res = publish(cmd)

    log && Logger.info fn -> "published timesync #{inspect(res)}" end

    :timer.sleep(frequency)

    if forever or ((loops - 1) > 0) do
      Keyword.replace(opts, :loops, (loops-1)) |>
        timesync_cmd_task()

      :executed_requested_loops
    end
  else
    :timesync_missing_config
  end

end


#
# Support Functions
#

defp publish_opts(topic, msg)
when is_binary(topic) and is_binary(msg) do
  [topic: topic, message: msg, dup: 0, qos: 0, retain: 0]
end

defp config(key)
when is_atom(key) do
  get_env(:mcp, Command.Control) |> Keyword.get(key)
end

end
