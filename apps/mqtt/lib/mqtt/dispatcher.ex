defmodule Mqtt.Dispatcher do
@moduledoc """
"""
require Logger
use GenServer
import Process, only: [send_after: 3]

alias Mcp.Cmd
alias Mcp.Reading
alias Mqtt.Client
alias Mqtt.Dispatcher

#  def child_spec(opts) do
#
#    %{
#      id: Mercurial.Mqtt.Client,
#      start: {Mercurial.Mqtt.Client, :start_link, [opts]},
#      restart: :permanent,
#      shutdown: 5000,
#      type: :supervisor
#    }
#  end

def start_link(s) do
  GenServer.start_link(__MODULE__, s, name: __MODULE__)
end

## Callbacks

def init(s)
when is_map(s) do
  Logger.info("#{__MODULE__} init() invoked")

  send_after(self(), {:startup}, 10)
  send_after(self(), {:timesync_cmd}, 11)

  {:ok, s}
end

# internal work functions
def incoming_message(msg)
when is_binary(msg) do
  GenServer.cast(__MODULE__, {:incoming_message, msg})
end

defp log_reading(%Reading{} = r) do
  if Reading.temperature?(r) do
    Logger.info fn ->
      ~s(#{r.host} #{r.device} #{r.friendly_name} #{r.tc} #{r.tf})
    end
  end

  if Reading.relhum?(r) do
    Logger.info fn ->
      ~s(#{r.host} #{r.device} #{r.friendly_name} #{r.tc} #{r.tf} #{r.rh})
    end
  end

  if Reading.startup?(r) do
    Logger.info("#{__MODULE__} received client startup announcement")
    send_after(self(), {:timesync_cmd}, 0)
  end
end

defp publish_opts(topic, msg)
when is_binary(topic) and is_binary(msg) do
  [topic: topic, message: msg, dup: 0, qos: 0, retain: 0]
end

# GenServer callbacks
def handle_cast({:incoming_message, msg}, s)
when is_binary(msg) and is_map(s) do
  r = Reading.decode!(msg)
  log_reading(r)

  {:noreply, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  # Logger.info("#{__MODULE__} :startup")

  {:noreply, s}
end

def handle_info({:timesync_cmd}, s)
when is_map(s) do
  Logger.info("#{__MODULE__} publishing timesync command")
  feed = Application.get_env(:mcp, Mqtt.Client) |> Keyword.get(:cmd_feed)
  msg = Cmd.timesync() |> Cmd.json()
  opts = publish_opts(feed, msg)

  Client.publish(opts)

  send_after(self(), {:timesync_cmd}, 300_000)
  {:noreply, s}
end

end
