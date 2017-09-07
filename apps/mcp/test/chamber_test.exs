defmodule ChamberTest do
  @moduledoc :false

  use ExUnit.Case

  alias Mcp.Chamber

  test "can get state from Chamber GenServer?" do
    assert is_map(Chamber.get_state())
  end

  test "are there any chambers?" do
    chambers = Chamber.known()

    assert Enum.count(chambers) > 0
  end

  test "can enable a chamber?" do
    res = Chamber.enable("test chamber")
    :timer.sleep(3_000)
    assert res == :ok
  end

  test "can disable a chamber?" do
    res = Chamber.disable("test chamber")
    :timer.sleep(3_000)
    Chamber.enable("test chamber")
    assert res == :ok
  end

  test "are there :new_device(s) in Chamber device?" do
    s = Chamber.get_state()

    c = s.chambers
    rs = Map.get(c, "test chamber")

    heater = Map.get(rs, :heater)
    name = Map.get(heater, :name)
    ctrl_dev = Map.get(heater, :ctrl_dev)

    assert (name != :new_device) and (name != :nil) and (ctrl_dev == "buzzer")
  end

  test "can get chamber status by name?" do
    msg = Chamber.status("test chamber")
    assert is_list(msg)
  end

  test "can get chamber status by name and print?" do
    r = Chamber.status("test chamber", :print)
    assert :ok == r 
  end
 
  test "can pass an unknown chamber name into status?" do
    msg = Chamber.status("not a chamber")
    assert msg == ["unknown chamber"]
  end 
end
