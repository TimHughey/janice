defmodule Seed.Sensors do
  @moduledoc """
  """

  def sensors(env) when env in [:dev, :test] do
    s =
      for i <- 10..20 do
        %Sensor{name: "test relhum #{i}", device: "2ic/relhum_device#{i}", type: "relhum"}
      end

    [
      %Sensor{name: "test temperature 1", device: "ds/test_device1", type: "temp"},
      %Sensor{name: "test temperature 2", device: "ds/test_device2", type: "temp"},
      %Sensor{name: "test temperature 3", device: "ds/test_device3", type: "temp"},
      %Sensor{name: "test relhum 1", device: "i2c/relhum_device1", type: "relhum"},
      %Sensor{name: "test relhum 2", device: "i2c/relhum_device2", type: "relhum"},
      %Sensor{name: "test relhum 3", device: "i2c/relhum_device3", type: "relhum"},
      %Sensor{name: "test relhum 4", device: "i2c/relhum_device4", type: "relhum"},
      %Sensor{name: "test relhum 5", device: "i2c/relhum_device5", type: "relhum"}
    ] ++ s
  end

  def sensors(:prod) do
    [
      %Sensor{name: "attic", device: "ds/28916149060000", type: "temp"},
      %Sensor{name: "hvac2_supply", device: "ds/28ee5815221500", type: "temp"},
      %Sensor{name: "hvac2_high_side", device: "ds/28ee6f0c231500", type: "temp"},
      %Sensor{name: "hvac2_low_side", device: "ds/28eef33c231500", type: "temp"},
      %Sensor{name: "sump_intake", device: "ds/28f566dd060000", type: "temp"},
      %Sensor{name: "chamber2_pri", device: "ds/28ff11c3501604", type: "temp"},
      %Sensor{name: "heat_test", device: "ds/28ff27da701605", type: "temp"},
      %Sensor{name: "hvac1_low_side", device: "ds/28ff2c62521604", type: "temp"},
      %Sensor{name: "sump_ambient", device: "ds/28ff2d30651401", type: "temp"},
      %Sensor{name: "display_tank", device: "ds/28ff2f70521604", type: "temp"},
      %Sensor{name: "washer_drain", device: "ds/28ff3824711603", type: "temp"},
      %Sensor{name: "exterior_ne", device: "ds/28ff61c0711603", type: "temp"},
      %Sensor{name: "hvac1_return", device: "ds/28ff8e62651401", type: "temp"},
      %Sensor{name: "mixtank", device: "ds/28ff9e77471603", type: "temp"},
      %Sensor{name: "hvac2_return", device: "ds/28ffb50cb81401", type: "temp"},
      %Sensor{name: "workbench", device: "ds/28ffbcda471603", type: "temp"},
      %Sensor{name: "chamber1_exhaust", device: "ds/28ffc7fc701605", type: "temp"},
      %Sensor{name: "exterior_se", device: "ds/28ffce823c0400", type: "temp"},
      %Sensor{name: "chamber2_sec", device: "ds/28ffd2db471603", type: "temp"},
      %Sensor{name: "hvac1_high_side", device: "ds/28ffda99521604", type: "temp"},
      %Sensor{name: "dryer_exhaust", device: "ds/28ffde95711603", type: "temp"},
      %Sensor{name: "chamber1_sec", device: "ds/28ffe4ad471603", type: "temp"},
      %Sensor{name: "mist_tank", device: "ds/28ffe865711604", type: "temp"},
      %Sensor{name: "sump_discharge", device: "ds/28fff5823c0400", type: "temp"},
      %Sensor{name: "laundry_room", device: "ds/28fff72b711603", type: "temp"},
      %Sensor{name: "hvac1_supply", device: "ds/28fff86d521604", type: "temp"},
      %Sensor{name: "basement", device: "ds/28fffd77711604", type: "temp"},
      %Sensor{name: "bistro", device: "i2c/f8f005e755da.01.sht31", type: "relhum"},
      %Sensor{name: "attic_equip_room", device: "i2c/f8f005e92917.00.sht31", type: "relhum"},
      %Sensor{name: "basement_equip_room", device: "i2c/f8f005e944e2.00.sht31", type: "relhum"},
      %Sensor{name: "chamber1_pri", device: "i2c/f8f005e944e2.01.am2315", type: "relhum"}
    ]
  end
end