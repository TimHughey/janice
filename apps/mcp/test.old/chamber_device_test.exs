defmodule ChamberDeviceTest do
  use ExUnit.Case, async: true

  test "can create a Chamber.Device?" do
    dev = Mcp.Chamber.Device.create(:cdev, "buzzer")

    assert dev.name == :cdev and dev.ctrl_dev == "buzzer"
  end

  test "can set a Chamber device to running?" do
    dev = Mcp.Chamber.Device.create(:cdev, "buzzer")
    dev = Mcp.Chamber.Device.run(dev, :nil)

    assert dev.name == :cdev and dev.status == :running
  end

  test "can set a Chamber device to idling?" do
    dev = Mcp.Chamber.Device.create(:cdev, "buzzer")
    dev = Mcp.Chamber.Device.idle(dev, :nil)

    assert dev.name == :cdev and dev.status == :idling
  end
end
