defmodule SensorTest do
  alias Mcp.Sensor

  use Timex
  use ExUnit.Case, async: false 

  setup_all do
    :ok
  end

  test "can create a sensor" do
    n = random()
    r = random()
    d = random()
    v = random(:float)
    s = %Sensor{name: n, reading: r, description: d, value: v}

    assert is_map(s)
  end

  test "can add a sensor" do
    n = random()
    r = random()
    d = random()
    v = random(:float)
    s = %Sensor{name: n, reading: r, description: d, value: v}

    {result, ns} = Sensor.add(s)

    assert :ok == result and is_map(ns)
  end

  test "can use Mcp.Sensor.persist with a Reading?" do
    alias Mcp.Reading
    n = random()
    k = random()
    v = random(:float)

    r = Reading.create(n, k, v)
    {result, ns} = Sensor.persist(r)

    assert :ok == result and is_tuple(ns)
  end

#  test "can auto populate from OWFS" do
#    count = Sensor.auto_populate()
#
#    assert count > 0
#  end

  test "the basic truth" do
    assert 1 + 1 == 2
  end

  def random do
    :crypto.strong_rand_bytes(10) |> Base.hex_encode32 |> String.downcase
  end

  def random(:float) do 
#    :rand.seed(:erlang.phash2([node()]), :erlang.monotonic_time(), :erlang.unique_integer())
    :rand.uniform(100) + :rand.uniform(100) / 100.0 |> Float.round(3)  
  end
end
