
defmodule Mix.Tasks.Seed do
@moduledoc """
  Seeds the Mercurial database
"""
require Logger
use Mix.Task

alias Mcp.Chamber
alias Mcp.DevAlias
#alias Mcp.Sensor

def run(_args) do
  Mix.Task.run "app.start", []
  dev_aliases(Mix.env) |> seed_dev_alias()
end

def chambers(_env) do
  [%Chamber{name: "main grow", description: "production",
            enable: true,
            temp_sensor_pri: "grow_pri_sensor",
            temp_sensor_sec: "grow_sec_sensor",
            temp_setpt: 80,
            heat_sw: "grow_heater", heat_control_ms: 20_000,
            relh_sensor: "grow_pri_sensor", relh_setpt: 93,
            relh_sw: "grow_mist", relh_control_ms: 15_000,
            relh_freq_ms: 2_376_000,
            relh_dur_ms: 60_000,
            air_stir_sw: "grow_stir", air_stir_temp_diff: 0.5,
            fresh_air_sw: "grow_fresh_air",
            fresh_air_freq_ms: 3_240_000, fresh_air_dur_ms: 360_000,
            warm: true, mist: true, fae: true, stir: true}]
end

def dev_aliases(_env) do
  [{"ds/291d1823000000:0", "led1", "dev led"},
   {"ds/12128521000000:0", "buzzer", "dev buzzer"},
   {"ds/28ff5733711604", "temp_probe1_dev", "dev temp probe1"},
   {"ds/28ffa442711604", "temp_probe2_dev", "dev temp probe2"},
   {"i2c/f8f005f73b53.04.am2315", "rhum_probe01_dev", "dev i2c probe01"},
   {"i2c/f8f005f73b53.01.sht31", "rhum_chip01_dev", "dev i2c chip01"},
   {"ds/ff000102030405", "tst_temp03", "tst temp 03"},
   {"ds/ffff0001020304", "tst_temp04", "tst temp 04"},
   # PRODUCION - attic
   {"ds/28916149060000", "attic", "attic ambient"},
   {"ds/28ffb50cb81401", "hvac2_return", "hvac2 return"},
   {"ds/28ee5815221500", "hvac2_supply", "hvac2 supply"},
   {"ds/28ee6f0c231500", "hvac2_high_side", "hvac2 compressor high side"},
   {"ds/28eef33c231500", "hvac2_low_side", "hvac2 compressor low side"},
   # PRODUCTION - basement
   {"ds/28fffd77711604", "basement", "basement ambient"},
   {"ds/28ffbcda471603", "workbench", "workbench ambient"},
   {"ds/28ff61c0711603", "exterior_ne", "northeast exterior"},
   {"ds/28ffce823c0400", "exterior_se", "southeast exterior"},
   {"ds/28ffde95711603", "dryer_exhaust", "dryer exhaust vent"},
   {"ds/28fff72b711603", "laundry_room", "laundry room ambient"},
   {"ds/28ff3824711603", "washer_drain", "washer drain water"},
   {"ds/28ff8e62651401", "hvac1_return", "hvac1 return"},
   {"ds/28fff86d521604", "hvac1_supply", "hvac1 supply"},
   {"ds/28ffda99521604", "hvac1_high_side", "hvac1 compressor high side"},
   {"ds/28ff2c62521604", "hvac1_low_side", "hvac1 compressor low side"},
   # PRODUCTION - chambers
   {"ds/28ffe865711604", "mist_tank", "chamber mist tank"},
   {"ds/28ffe4ad471603", "chamber1_sec", "grow chamber secondary"},
   {"ds/28ffc7fc701605", "chamber1_exhaust", "grow chamber exhaust"},
   {"ds/28ff11c3501604", "chamber2_pri", "womb chamber primary"},
   {"ds/28ffd2db471603", "chamber2_sec", "womb chamber secondary"},
   # PRODUCTION - reef tank
   {"ds/28ff2f70521604", "display_tank", "reef display tank"},
   {"ds/28ff2d30651401", "sump_ambient", "sump area ambient air"},
   {"ds/28f566dd060000", "sump_intake", "reef sump intake"},
   {"ds/28fff5823c0400", "sump_discharge", "reef sump discharge (return)"},
   {"ds/28ff9e77471603", "mixtank", "mixtank water"},
   # PRODUCTION - switches
   {"ds/12328621000000:1", "mixtank_heater", "reef mixtank heater (sys_p3)"},
   {"ds/12328621000000:0", "loop_indicator", "visual indicator (sys_p3)"},
   {"ds/12376621000000:1", "shroom1_heat", "chamber1 heater (sys_p2)"},
   {"ds/12606e21000000:1", "shroom2_heat", "chamber2 heater (sys_p1)"},
   {"ds/29463408000000:0", "shroom1_mist", "chamber1 mist (io1)"},
   {"ds/29463408000000:1", "mixtank_air", "mixtank air pump (io1)"},
   {"ds/29463408000000:3", "reefmix_rodi_valve", "reef mixtank rodi (io1)"},
   {"ds/29463408000000:4", "shroom1_fresh_air", "chamber1 fresh air (io1)"},
   {"ds/29463408000000:5", "shroom2_stir", "chamber2 circulation (io1)"},
   {"ds/29463408000000:6", "shroom1_air", "chamber1 air pump (io1)"},
   {"ds/29463408000000:7", "am2315_pwr", "am2315 power"},
   {"ds/12197521000000:1", "mixtank_pump", "reef mixtank circ pump (sys_buzzer)"}]
end

def seed_dev_alias([]), do: []
def seed_dev_alias({device, fname, desc}) do
  Logger.info "seeding #{device} #{fname}"
  %DevAlias{device: device, friendly_name: fname, description: desc} |>
    DevAlias.add()
end

def seed_dev_alias([da | list]) do
  [seed_dev_alias(da)] ++ seed_dev_alias(list)
end

end
