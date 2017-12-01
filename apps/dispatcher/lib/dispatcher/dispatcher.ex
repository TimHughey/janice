defmodule Dispatcher.InboundMessage do
@moduledoc """
"""
require Logger
use GenServer
import Application, only: [get_env: 2]
import Process, only: [send_after: 3]

alias Dispatcher.Reading
alias Fact.FreeRamStat
alias Fact.RunMetric

import Command.Control, only: [send_timesync: 0]

def start_link(s) do
  GenServer.start_link(Dispatcher.InboundMessage, s,
                        name: Dispatcher.InboundMessage)
end

## Callbacks

def init(s)
when is_map(s) do
  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, config(:startup_delay_ms))
    false -> nil
  end

  s = Map.put_new(s, :log_reading, config(:log_reading))
  s = Map.put_new(s, :messages_dispatched, 0)

  Logger.info("init()")

  {:ok, s}
end

# internal work functions
def process(msg)
when is_binary(msg) do
  GenServer.cast(Dispatcher.InboundMessage, {:incoming_message, msg})
end

defp log_reading(%Reading{}, false), do: nil
defp log_reading(%Reading{} = r, true) do
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
end

# GenServer callbacks
def handle_cast({:incoming_message, msg}, s)
when is_binary(msg) and is_map(s) do
  r = Reading.decode!(msg)
  log_reading(r, s.log_reading)

  if Reading.startup?(r) do
    Logger.info("#{r.host} version #{r.version} announced startup")
    send_timesync()
  end

  if Reading.temperature?(r) || Reading.relhum?(r) do
    {mod, func} = config(:temperature_msgs)
    # Logger.info(msg)
    apply(mod, func, [Reading.as_map(r)])
    #Sensor.external_update(Reading.as_map(r))
  end

  if Reading.switch?(r) do
    {mod, func} = config(:switch_msgs)
    # if not Reading.cmdack?(r), do: Logger.info(msg)
    apply(mod, func, [Reading.as_map(r)])
    #Switch.external_update(Reading.as_map(r))
  end

  if Reading.free_ram_stat?(r) do
    # Logger.info("#{msg}")
    FreeRamStat.record(remote_host: r.host, val: r.freeram)
  end

  s = %{s | messages_dispatched: s.messages_dispatched + 1}
  RunMetric.record(module: "#{__MODULE__}", application: "mercurial",
    metric: "msgs_dispatched", val: s.messages_dispatched)

  {:noreply, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  send_after(self(), {:periodic_log}, config(:periodic_log_first_ms))
  # Logger.info("#{Dispatcher.InboundMessage} :startup")

  {:noreply, s}
end

def handle_info({:periodic_log}, s)
when is_map(s) do
  Logger.info("messages dispatched: #{s.messages_dispatched}")

  send_after(self(), {:periodic_log}, config(:periodic_log_ms))

  {:noreply, s}
end

defp config(key)
when is_atom(key) do
  get_env(:dispatcher, Dispatcher.InboundMessage) |> Keyword.get(key)
end

end
