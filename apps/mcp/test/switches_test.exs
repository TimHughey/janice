defmodule Mcp.SwitchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Mcp.Switch

  alias Mcp.Switch
  alias Mcp.DevAlias

  setup_all do
    # create a DevAlias for a device to control
    dev  = "ds/290011223344FF"
    led1 = "ds/291d1823000000"
    buzz = "ds/12128521000000"
    pump1 = %DevAlias{device: "#{dev}:0", friendly_name: "test_pump1",
                      description: "created for testing"}
    pump2 = %DevAlias{device: "#{dev}:1", friendly_name: "test_pump2",
                      description: "created for testing"}
    led1  = %DevAlias{device: "#{led1}:0", friendly_name: "led1",
                      description: "led created for testing"}
    buzz  = %DevAlias{device: "#{buzz}:0", friendly_name: "buzzer",
                      description: "buzzer created for testing"}

    DevAlias.add(pump1)
    DevAlias.add(pump2)
    DevAlias.add(led1)
    DevAlias.add(buzz)

    states = [%{pio: 0, state: true}, %{pio: 1, state: false}]

    Switch.add_or_update(%Switch{device: dev, states: states})
    :ok
  end

  test "get a switch state by friendly name" do
    state1 = Switch.state("test_pump1")
    state2 = Switch.state("test_pump2")

    assert (state1 == true) and (state2 == false)
  end

  # test "acknowledge a switch command" do
  #   %{cmd_ref: cmd_ref, state: _} = Switches.off("water_pump")
  #   %{cmd_dt: _, uuid: uuid} = cmd_ref
  #   {acked_uuid, latency} = Switches.ack_cmd("water_pump", uuid)
  #
  #   assert (acked_uuid === uuid) and (latency > 0)
  # end
  #
  # test "handle acknowledge with a non-existent uuid" do
  #   {acked_uuid, latency} = Switches.ack_cmd("water_pump", "bad_uuid")
  #
  #   assert is_nil(acked_uuid) and (latency == 0)
  # end

end
