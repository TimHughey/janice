defmodule Mcp.IExHelpers do

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

end
