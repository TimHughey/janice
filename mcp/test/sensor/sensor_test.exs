defmodule SensorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import JanTest
  # import ExUnit.CaptureLog

  @moduletag :sensor
  @moduletag report: [:device, :sensor]

  setup_all do
    :ok
  end

  setup_all do
    for j <- 0..10,
        _k <- 0..10,
        do: temp_ext_msg(j)

    # sensor011 has 40 readings in two groups separated by 2 seconds
    for _j <- 0..20, do: temp_ext_msg(11, tc: 100)
    :timer.sleep(2000)
    for _j <- 0..20, do: temp_ext_msg(11, tc: 50)

    :ok
  end

  setup context do
    if num = context[:num] do
      device = sen_dev(num)

      sensor = Sensor.get_by(device: device)
      [device: device, sensor: sensor]
    else
      :ok
    end
  end

  test "the truth will set you free" do
    assert true === true
    refute false
  end

  @tag num: 1
  test "can create a sensor via an inbound message", context do
    sensor = context[:sensor]

    assert sensor
  end

  @tag num: 2
  test "can get avg temperature (F)", context do
    tf = Sensor.fahrenheit(device: context[:device])

    assert is_number(tf)
  end

  @tag num: 2
  test "can get avg temperature (C)", context do
    tf = Sensor.celsius(device: context[:device])

    assert is_number(tf)
  end

  @tag num: 2
  test "can get avg temperature map", context do
    map = Sensor.temperature(device: context[:device])

    tf = Map.get(map, :tf)
    tc = Map.get(map, :tc)

    assert is_number(tf)
    assert is_number(tc)
  end

  @tag num: 9
  test "can deprecate a sensor", context do
    id = context[:sensor] |> Map.get(:id)
    {rc, sensor} = Sensor.deprecate(id)

    assert rc == :ok and String.contains?(sensor.name, "~")
  end

  # sensor011 has temperatures of all the same value
  @tag num: 11
  test "average is calculated correctly", context do
    tc = Sensor.celsius(device: context[:device], since_secs: 1)

    assert tc === 50.0
  end

  test "can handle unknown sensor" do
    tc = Sensor.celsius(device: "bad_sensor", since_secs: 60)

    assert is_nil(tc)
  end

  test "can purge SensorTemperature readings" do
    {count, returned} = SensorTemperature.purge_readings(days: -1)

    assert count >= 0 and is_nil(returned)
  end

  test "can purge SensorRelHum readings" do
    {count, returned} = SensorRelHum.purge_readings(days: -1)

    assert count >= 0 and is_nil(returned)
  end
end
