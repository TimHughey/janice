
defmodule Mix.Tasks.Seed do
@moduledoc """
  Seeds the Mercurial database
"""
use Mix.Task

alias Mcp.DevAlias
#alias Mcp.Sensor

def run(_args) do
  Mix.Task.run "app.start", []

  if Mix.env == :dev or Mix.env == :test do
    dev_aliases(Mix.env) |> seed_dev_alias()
  end
end

def dev_aliases(env)
when env == :dev or env == :test do
  [{"ds/291d1823000000:0", "led1", "dev led"},
   {"ds/12128521000000:0", "buzzer", "dev buzzer"},
   {"ds/28ff5733711604", "temp_probe1_dev", "dev temp probe1"},
   {"ds/28ffa442711604", "temp_probe2_dev", "dev temp probe2"},
   {"i2c/f8f005f73b53.04.am2315", "rhum_probe01", "dev i2c probe01"},
   {"i2c/f8f005f73b53.01.sht31", "rhum_chip01", "dev i2c chip01"},
   {"ds/ff000102030405", "tst_temp03", "tst temp 03"},
   {"ds/ffff0001020304", "tst_temp04", "tst temp 04"},
   # PRODUCION - attic
   {"ds/28.916149060000", "attic", "attic ambient"},
   {"ds/28.ffb50cb81401", "hvac2_return", "hvac2 return"},
   {"ds/28.ee5815221500", "hvac2_supply", "hvac2 supply"},
   {"ds/28.ee6f0c231500", "hvac2_high_side", "hvac2 compressor high side"},
   {"ds/28.eef33c231500", "hvac2_low_side", "hvac2 compressor low side"},
   # PRODUCTION - basement
   {"ds/28.fffd77711604", "basement", "basement ambient"},
   {"ds/28.ffbcda471603", "workbench", "workbench ambient"},
   {"ds/28.ff61c0711603", "exterior_ne", "northeast exterior"},
   {"ds/28.ffce823c0400", "exterior_se", "southeast exterior"},
   {"ds/28.ffde95711603", "dryer_exhaust", "dryer exhaust vent"},
   {"ds/28.fff72b711603", "laundry_room", "laundry room ambient"},
   {"ds/28.ff3824711603", "washer_drain", "washer drain water"},
   {"ds/28.ff8e62651401", "hvac1_return", "hvac1 return"},
   {"ds/28.fff86d521604", "hvac1_supply", "hvac1 supply"},
   {"ds/28.ffda99521604", "hvac1_high_side", "hvac1 compressor high side"},
   {"ds/28.ff2c62521604", "hvac1_low_side", "hvac1 compressor low side"},
   # PRODUCTION - chambers
   {"ds/28.ffe865711604", "mist_tank", "chamber mist tank"},
   {"ds/28.ffe4ad471603", "chamber1_sec", "grow chamber secondary"},
   {"ds/28.ffc7fc701605", "chamber1_exhaust", "grow chamber exhaust"},
   {"ds/28.ff11c3501604", "chamber2_pri", "womb chamber primary"},
   {"ds/28.ffd2db471603", "chamber2_sec", "womb chamber secondary"},
   # PRODUCTION - reef tank
   {"ds/28.ff2f70521604", "display_tank", "reef display tank"},
   {"ds/28.ff2d30651401", "sump_ambient", "sump area ambient air"},
   {"ds/28.f566dd060000", "sump_intake", "reef sump intake"},
   {"ds/28.fff5823c0400", "sump_discharge", "reef sump discharge (return)"},
   {"ds/28.ff9e77471603", "mixtank", "mixtank water"},
   # PRODUCTION - switches
   {"ds/12.328621000000:1", "mixtank_heater", "reef mixtank heater (sys_p3)"},
   {"ds/12.328621000000:0", "loop_indicator", "visual indicator (sys_p3)"},
   {"ds/12.376621000000:1", "shroom1_heat", "chamber1 heater (sys_p2)"},
   {"ds/12.606e21000000:1", "shroom2_heat", "chamber2 heater (sys_p1)"},
   {"ds/29.463408000000:0", "shroom1_mist", "chamber1 mist (io1)"},
   {"ds/29.463408000000:1", "mixtank_air", "mixtank air pump (io1)"},
   {"ds/29.463408000000:3", "reefmix_rodi_valve", "reef mixtank rodi (io1)"},
   {"ds/29.463408000000:4", "shroom1_fresh_air", "chamber1 fresh air (io1)"},
   {"ds/29.463408000000:5", "shroom2_stir", "chamber2 circulation (io1)"},
   {"ds/29.463408000000:6", "shroom1_air", "chamber1 air pump (io1)"},
   {"ds/29.463408000000:7", "am2315_pwr", "am2315 power"},
   {"ds/12.197521000000:1", "mixtank_pump", "reef mixtank circ pump (sys_buzzer)"}

  ]
end

def seed_dev_alias([]), do: []
def seed_dev_alias({device, fname, desc}) do
  %DevAlias{device: device, friendly_name: fname, description: desc} |>
    DevAlias.add()
end
def seed_dev_alias([da | list]) do
  [seed_dev_alias(da)] ++ seed_dev_alias(list)
end

end
