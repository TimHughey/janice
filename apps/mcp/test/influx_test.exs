defmodule InfluxTest do
  use ExUnit.Case, async: true 

  alias Mcp.{Influx, Influx.Position, Reading, Duration}

  test "can create a Position?" do
    p = Position.new("test switch", :true)

    assert p.switch == "test switch" 
  end

  test "can create a Reading and post to Influx?" do
    good_val = {100, {:ok, 85.0}}
    r = Reading.create("ts_test1", "temperature", good_val)

    assert :ok = Influx.post(r)
  end

  test "can create a Duration and post to Influx?" do
    d = Duration.create("test_duration", 1024)

    assert :ok = Influx.post(d)
  end

  test "the truth" do
    assert 1 + 1 == 2
  end
end
