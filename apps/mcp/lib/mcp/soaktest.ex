defmodule Mcp.SoakTest do
@moduledoc """
"""
require Logger
use GenServer
import Application, only: [get_env: 2]
import Process, only: [send_after: 3]

alias Mcp.Switch
alias Fact.LedFlashes

def start_link(s) do
  GenServer.start_link(Mcp.SoakTest, s,
                        name: Mcp.SoakTest)
end

## Callbacks

def init(s)
when is_map(s) do
  case Map.get(s, :autostart, false) do
    true  -> send_after(self(), {:startup}, config(:startup_delay_ms))
    false -> nil
  end

  s = Map.put_new(s, :led_flashes, 0)

  Logger.info("init()")

  {:ok, s}
end

# GenServer callbacks
def handle_info({:flash_led}, s) do
  dev = "led1"
  led_flashes = s.led_flashes + 1

  Switch.set_state(dev, true)
  Switch.set_state(dev, false)

  LedFlashes.record(application: "mcp_soaktest",
    friendly_name: dev, val: led_flashes)

  s = %{s | led_flashes: led_flashes}

  send_after(self(), {:flash_led}, config(:flash_led_ms))

  {:noreply, s}
end

def handle_info({:startup}, s)
when is_map(s) do
  send_after(self(), {:periodic_log}, config(:periodic_log_first_ms))
  send_after(self(), {:flash_led}, config(:flash_led_ms))

  {:noreply, s}
end

def handle_info({:periodic_log}, s)
when is_map(s) do
  Logger.info("led flashes: #{s.led_flashes}")

  send_after(self(), {:periodic_log}, config(:periodic_log_ms))

  {:noreply, s}
end

defp config(key)
when is_atom(key) do
  get_env(:mcp, Mcp.SoakTest) |> Keyword.get(key)
end

end
