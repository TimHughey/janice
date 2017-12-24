defmodule Mcp.IExHelpers do

use Timex
alias Mqtt.Client
@moduledoc """
"""
# def main_grow do
#   Mcp.Chamber.status("main grow", :print)
# end

def led1_state(state) do
  SwitchState.state("led1", state)
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

def make_mtime_current(json) do
  mtime = Timex.now() |> Timex.to_unix
  Poison.decode!(json, [keys: :atoms]) |>
    Map.put(:mtime, mtime) |>
    Poison.encode!()
end

def change_device(json, device) do
  Poison.decode!(json, [keys: :atoms]) |>
    Map.put(:device, device) |>
    Poison.encode!()
end

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

  make_mtime_current(json) |>
    change_device(device) |>
    Dispatcher.InboundMessage.process()
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

  make_mtime_current(json) |>
    change_device(device) |>
    Dispatcher.InboundMessage.process()
end

def switch_json do
  ~s|{"version":"aac8961",
      "host":"mcr.f8f005e755da",
      "device":"ds/12838421000000",
      "mtime":1512862673,
      "type":"switch",
      "pio_count":2,
      "states":[{"pio":0,"state":true},{"pio":1,"state":true}]}|
end

def switch_test do
  switch_test("ds/2pos1")
end

def switch_test(device) do
  switch_json() |>
    make_mtime_current() |>
    change_device(device) |>
    Dispatcher.InboundMessage.process()
end

def ack_a_cmd do
  cmd = SwitchCmd.unacked() |> hd
  states =
    Enum.map(cmd.switch.states, fn(x) -> %{pio: x.pio, state: x.state} end)
  pio_count = Enum.count(states)

  %{version: "aac8961",
    host: "mcr.f8f005e755da",
    device: cmd.switch.device,
    mtime: (Timex.now() |> Timex.to_unix),
    type: "switch",
    pio_count: pio_count,
    states: states,
    refid: cmd.refid,
    cmdack: true} |> Poison.encode!() |> Dispatcher.InboundMessage.process()
end

def switch_state_test(name, count, states \\ [true, false]) do
  for _i <- 0..count, j <- states do
    SwitchState.state(name, j)
    ack_a_cmd()
  end

  ack_a_cmd()

  :ok
end

end ## defmodule end
