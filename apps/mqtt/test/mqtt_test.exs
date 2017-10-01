defmodule MqttTest do
  use ExUnit.Case
  doctest Mqtt

  test "greets the world" do
    assert Mqtt.hello() == :world
  end
end
