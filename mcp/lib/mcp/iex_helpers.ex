defmodule Mcp.IExHelpers do

use Timex
alias Mcp.Switch
alias Mqtt.Client
@moduledoc """
"""
# def main_grow do
#   Mcp.Chamber.status("main grow", :print)
# end

def led1_state(state) do
  Switch.set_state("led1", state)
  :ok
end

def led1_on do
  led1_state(true)
  :ok
end

def led1_off do
  led1_state(false)
  :ok
end

def led1_flash do
  led1_state(false)
  led1_state(true)
  led1_state(false)
end

def mqtt_start do
  Client.connect()
  Client.report_subscribe()
end

def server_state(mod), do: :sys.get_state(mod)

def tsensor_test do
  tsensor_test("ds/test_device4")
end

def tsensor_test(device) do
  json = ~s|{"version":"aac8961",
            "host":"mcr.f8f005e944e2",
            "device":"ds/test_device4",
            "mtime":1512862674,
            "type":"temp",
            "tc":17.25,
            "tf":63.05}|

  mtime = Timex.now() |> Timex.to_unix
  map = Poison.decode!(json, [keys: :atoms])
  map = %{map | mtime: mtime, device: device}

  json = Poison.encode!(map)

  Dispatcher.InboundMessage.process(json)
end

def rsensor_test do
  rsensor_test("i2c/relhum_device4")
end

def rsensor_test(device) do
  json = ~s|{"version":"aac8961",
            "host":"mcr.f8f005e944e2",
            "device":"i2c/relhum_device4",
            "mtime":1512862674,
            "type":"temp",
            "tc":17.25,
            "tf":63.05,
            "rh":45.32}|

  mtime = Timex.now() |> Timex.to_unix
  map = Poison.decode!(json, [keys: :atoms])
  map = %{map | mtime: mtime, device: device}

  json = Poison.encode!(map)

  Dispatcher.InboundMessage.process(json)
end

end
