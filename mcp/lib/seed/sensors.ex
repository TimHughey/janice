defmodule Seed.Sensors do
  @moduledoc """
  """

  def sensors(:dev) do
    [%Sensor{name: "test temperature 1",
              device: "ds/test_device1",
              type: "temp"},
     %Sensor{name: "test temperature 2",
              device: "ds/test_device2",
              type: "temp"},
     %Sensor{name: "test temperature 3",
              device: "ds/test_device3",
              type: "temp"},
     %Sensor{name: "test relhum 1",
              device: "i2c/relhum_device1",
              type: "relhum"},
     %Sensor{name: "test relhum 2",
              device: "i2c/relhum_device2",
              type: "relhum"},
     %Sensor{name: "test relhum 3",
              device: "i2c/relhum_device3",
              type: "relhum"}]
  end

end
