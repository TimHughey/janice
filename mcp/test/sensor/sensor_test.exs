defmodule SensorTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  import JanTest
  # import ExUnit.CaptureLog
  use Timex

  @moduletag :sensor
  @moduletag report: [:device, :sensor]

  setup_all do
    :ok
  end

  setup context do
    if num = context[:num] do
      device = sen_dev(num)

      # record many temperatures
      for _i <- 0..10, do: temp_ext_msg(num)

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
end
