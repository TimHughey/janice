defmodule MqttSetSwitchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Mqtt.SetSwitch

  def states, do: [%{pio: 0, state: true}, %{pio: 1, state: false}]
  def refid, do: "11111-22222"

  test "create switchcmd (unspecified ack)" do
    cmd = SetSwitch.new_cmd("ds/device", states(), refid())

    # should be nil since it will default to true within the remote device when undefined
    ack = Map.get(cmd, :ack)

    assert is_map(cmd)
    assert ack
  end

  test "create switchcmd (ack is false)" do
    cmd = SetSwitch.new_cmd("ds/device", states(), refid(), ack: false)

    # should be nil since it will default to true within the remote device when undefined
    ack = Map.get(cmd, :ack)

    assert is_map(cmd)
    refute ack
  end

  test "create switchmd (ack is true)" do
    cmd = SetSwitch.new_cmd("ds/device", states(), refid(), ack: true)

    # should be nil since it will default to true within the remote device when undefined
    ack = Map.get(cmd, :ack)

    assert is_map(cmd)
    assert ack
  end
end
