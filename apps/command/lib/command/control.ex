defmodule Command.Control do
@moduledoc """
"""
require Logger
use GenServer

import Application, only: [get_env: 2]
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
  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, config(:startup_delay_ms))
             send_after(self(), {:timesync_cmd}, config(:startup_delay_ms) + 1)
    false -> nil
  end

  {:ok, s}
end

#
# External Functions
#
def send_timesync() do
  GenServer.cast(Command.Control, {:timesync})
end

#
# GenServer Callbacks
#

def handle_cast({:timesync_cmd}, s)
when is_map(s) do
  # reuse the code that periodic sending of timesync commands
  send_after(self(), {:timesync_cmd}, 0)

  {:noreply, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  # Logger.info("#{Command.Control} :startup")

  {:noreply, s}
end

def handle_info({:timesync_cmd}, s)
when is_map(s) do
  # Logger.info("publishing timesync command")
  msg = Timesync.new_cmd() |> Timesync.json()
  opts = publish_opts(config(:cmd_feed), msg)

  publish(opts)

  send_after(self(), {:timesync_cmd}, config(:periodic_timesync_ms))
  {:noreply, s}
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
  get_env(:command, Command.Control) |> Keyword.get(key)
end

end
