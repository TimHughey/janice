
defmodule Mix.Tasks.Seed do
@moduledoc """
  Seeds the Mercurial database
"""
require Logger
use Mix.Task

alias Mcp.Chamber
alias Mcp.DevAlias
alias Mcp.Dutycycle
alias Mcp.Mixtank
alias Mcp.Repo
#alias Mcp.Sensor

def run(_args) do
  Mix.Task.run "app.start", []
  dev_aliases(Mix.env) |> seed_dev_alias()
  mixtanks(Mix.env) |> seed_mixtank()
  chambers(Mix.env) |> seed()
  dutycycles(Mix.env) |> seed()
  mixtanks(Mix.env) |> seed()
end

def chambers(env)
when env == :dev or env == :test do
  []
end

def chambers(:prod) do
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
            warm: true, mist: true, fae: true, stir: true},
   %Chamber{name: "womb", description: "production womb",
             enable: true,
             temp_sensor_pri: "womb_pri_sensor",
             temp_sensor_sec: "womb_sec_sensor",
             temp_setpt: 80,
             heat_sw: "shroom2_heat", heat_control_ms: 20_000,
             relh_sensor: "womb_pri_sensor", relh_setpt: 93,
             relh_sw: "no_device", relh_control_ms: 15_000,
             relh_freq_ms: 2_376_000,
             relh_dur_ms: 60_000,
             air_stir_sw: "shroom2_stir", air_stir_temp_diff: 0.5,
             fresh_air_sw: "no_device",
             fresh_air_freq_ms: 3_240_000, fresh_air_dur_ms: 360_000,
             warm: true, mist: false, fae: false, stir: true}]
end

def dutycycles(env)
when env == :dev or env == :test do
  [%Dutycycle{name: "buzzer",
     description: "dutycycle test case",
     enable: false, device_sw: "buzzer",
     run_ms: 1000, idle_ms: 60 * 1000}]
end

def dutycycles(:prod) do
  [%Dutycycle{name: "sump vent",
     description: "sump vent",
     enable: false, device_sw: "sump_vent",
     run_ms: 20 * 60 * 1000, idle_ms: 2 * 60 * 1000},
   %Dutycycle{name: "basement circulation",
     description: "basement circulation fan",
     enable: true, device_sw: "basement_fan",
     run_ms: 15 * 60 * 1000, idle_ms: 60 * 1000},
   %Dutycycle{name: "reefmix rodi slow",
     description: "periodic fill reefmix with rodi water",
     enable: true, device_sw: "reefmix_rodi_valve",
     run_ms: 900_000, idle_ms: 300_000},
   %Dutycycle{name: "reefmix rodi fast",
     description: "fill mixtank quickly",
     enable: false, device_sw: "reefmix_rodi_valve",
     run_ms: 3_600_000, idle_ms: 120_000}]
end

def dev_aliases(env)
when env == :dev or env == :test do
  [{"ds/291d1823000000:0", "led1", "dev led"},
   {"ds/12128521000000:0", "buzzer", "dev buzzer"},
   {"ds/28ff5733711604", "temp_probe1_dev", "dev temp probe1"},
   {"ds/28ffa442711604", "temp_probe2_dev", "dev temp probe2"},
   {"i2c/f8f005f73b53.04.am2315", "rhum_probe01_dev", "dev i2c probe01"},
   {"i2c/f8f005f73b53.01.sht31", "rhum_chip01_dev", "dev i2c chip01"},
   {"ds/ff000102030405", "tst_temp03", "tst temp 03"},
   {"ds/ffff0001020304", "tst_temp04", "tst temp 04"}]
end

  # feather2 (ext antenna, pins): mcr.f8f005f73b53
  # attic MCR: mcr.
  # original MCR: mcr.f8f005f7401d
  # basement MCR
def dev_aliases(:prod) do
  [%DevAlias{device: "ds/12128521000000:0", friendly_name: "buzzer", description: "dev buzzer"},
   %DevAlias{device: "ds/12197521000000:1", friendly_name: "mixtank_pump", description: "reef mixtank circ pump (sys_buzzer)"},
   %DevAlias{device: "ds/12328621000000:0", friendly_name: "loop_indicator", description: "visual indicator (sys_p3)"},
   %DevAlias{device: "ds/12328621000000:1", friendly_name: "mixtank_heater", description: "reef mixtank heater (sys_p3)"},
   %DevAlias{device: "ds/12376621000000:1", friendly_name: "shroom1_heat", description: "chamber1 heater (sys_p2)"},
   %DevAlias{device: "ds/12606e21000000:1", friendly_name: "shroom2_heat", description: "chamber2 heater (sys_p1)"},
   %DevAlias{device: "ds/28916149060000", friendly_name: "attic", description: "attic ambient"},
   %DevAlias{device: "ds/28ee5815221500", friendly_name: "hvac2_supply", description: "hvac2 supply"},
   %DevAlias{device: "ds/28ee6f0c231500", friendly_name: "hvac2_high_side", description: "hvac2 compressor high side"},
   %DevAlias{device: "ds/28eef33c231500", friendly_name: "hvac2_low_side", description: "hvac2 compressor low side"},
   %DevAlias{device: "ds/28f566dd060000", friendly_name: "sump_intake", description: "reef sump intake"},
   %DevAlias{device: "ds/28ff11c3501604", friendly_name: "chamber2_pri", description: "womb chamber primary"},
   %DevAlias{device: "ds/28ff27da701605", friendly_name: "heat_test", description: "sensor for testing heater"},
   %DevAlias{device: "ds/28ff2c62521604", friendly_name: "hvac1_low_side", description: "hvac1 compressor low side"},
   %DevAlias{device: "ds/28ff2d30651401", friendly_name: "sump_ambient", description: "sump area ambient air"},
   %DevAlias{device: "ds/28ff2f70521604", friendly_name: "display_tank", description: "reef display tank"},
   %DevAlias{device: "ds/28ff3824711603", friendly_name: "washer_drain", description: "washer drain water"},
   %DevAlias{device: "ds/28ff61c0711603", friendly_name: "exterior_ne", description: "northeast exterior"},
   %DevAlias{device: "ds/28ff8e62651401", friendly_name: "hvac1_return", description: "hvac1 return"},
   %DevAlias{device: "ds/28ff9e77471603", friendly_name: "mixtank", description: "mixtank water"},
   %DevAlias{device: "ds/28ffb50cb81401", friendly_name: "hvac2_return", description: "hvac2 return"},
   %DevAlias{device: "ds/28ffbcda471603", friendly_name: "workbench", description: "workbench ambient"},
   %DevAlias{device: "ds/28ffc7fc701605", friendly_name: "chamber1_exhaust", description: "grow chamber exhaust"},
   %DevAlias{device: "ds/28ffce823c0400", friendly_name: "exterior_se", description: "southeast exterior"},
   %DevAlias{device: "ds/28ffd2db471603", friendly_name: "chamber2_sec", description: "womb chamber secondary"},
   %DevAlias{device: "ds/28ffda99521604", friendly_name: "hvac1_high_side", description: "hvac1 compressor high side"},
   %DevAlias{device: "ds/28ffde95711603", friendly_name: "dryer_exhaust", description: "dryer exhaust vent"},
   %DevAlias{device: "ds/28ffe4ad471603", friendly_name: "chamber1_sec", description: "grow chamber secondary"},
   %DevAlias{device: "ds/28ffe865711604", friendly_name: "mist_tank", description: "chamber mist tank"},
   %DevAlias{device: "ds/28fff5823c0400", friendly_name: "sump_discharge", description: "reef sump discharge (return)"},
   %DevAlias{device: "ds/28fff72b711603", friendly_name: "laundry_room", description: "laundry room ambient"},
   %DevAlias{device: "ds/28fff86d521604", friendly_name: "hvac1_supply", description: "hvac1 supply"},
   %DevAlias{device: "ds/28fffd77711604", friendly_name: "basement", description: "basement ambient"},
   %DevAlias{device: "ds/291d1823000000:0", friendly_name: "led1", description: "dev led"},
   %DevAlias{device: "ds/29463408000000:0", friendly_name: "shroom1_mist", description: "chamber1 mist (io1)"},
   %DevAlias{device: "ds/29463408000000:1", friendly_name: "mixtank_air", description: "mixtank air pump (io1)"},
   %DevAlias{device: "ds/29463408000000:3", friendly_name: "reefmix_rodi_valve", description: "reef mixtank rodi (io1)"},
   %DevAlias{device: "ds/29463408000000:4", friendly_name: "shroom1_fresh_air", description: "chamber1 fresh air (io1)"},
   %DevAlias{device: "ds/29463408000000:5", friendly_name: "shroom2_stir", description: "chamber2 circulation (io1)"},
   %DevAlias{device: "ds/29463408000000:6", friendly_name: "shroom1_air", description: "chamber1 air pump (io1)"},
   %DevAlias{device: "ds/29463408000000:7", friendly_name: "am2315_pwr", description: "am2315 power"},
   %DevAlias{device: "i2c/f8f005e755da.01.sht31", friendly_name: "bistro", description: "auto created for unknown device"},
   %DevAlias{device: "i2c/f8f005e92917.00.sht31", friendly_name: "attic_equip_room", description: "attic hvac closet ambient"},
   %DevAlias{device: "i2c/f8f005e944e2.00.sht31", friendly_name: "basement_equip_room", description: "auto created for unknown device"},
   %DevAlias{device: "i2c/f8f005e944e2.01.am2315", friendly_name: "chamber1_pri", description: "grow chamber primary"}]
end

def mixtanks(env)
when env == :dev or env == :test do
  []
end

def mixtanks(:prod) do
  [%Mixtank{name: "reefmix change",
    description: "reefwater change mode (full pump, no air)",
    enable: :false,
    sensor: "mixtank", ref_sensor: "display_tank",
    heat_sw: "mixtank_heater",
    air_sw: "mixtank_air",
    air_run_ms: 0, air_idle_ms: 3_600_000,
    pump_sw: "mixtank_pump",
    pump_run_ms: 3_600_000, pump_idle_ms: 0,
    state_at: Timex.now()},
  %Mixtank{name: "reefmix fill",
    description: "reefwater fill mode (pump only, no air)",
    enable: :false,
    sensor: "mixtank", ref_sensor: "display_tank",
    heat_sw: "mixtank_heater",
    air_sw: "mixtank_air",
    air_run_ms: 0, air_idle_ms: 3_600_000,
    pump_sw: "mixtank_pump",
    pump_run_ms: 60 * 60 * 1000, pump_idle_ms: 60 * 1000,
    state_at: Timex.now()},
  %Mixtank{name: "reefmix minimal",
    description: "reefwater minimal mode (pump minimal, air minimal)",
    enable: :false,
    sensor: "mixtank", ref_sensor: "display_tank",
    heat_sw: "mixtank_heater",
    air_sw: "mixtank_air",
    air_run_ms: 10 * 60 * 1000, air_idle_ms: 4 * 60 * 60 * 1000,
    pump_sw: "mixtank_pump",
    pump_run_ms: 10 * 60 * 1000, pump_idle_ms: 4 * 60 * 60 * 1000,
    state_at: Timex.now()},
  %Mixtank{name: "reefmix mix",
    description: "reefwater mix mode (pump max, air max)",
    enable: :false,
    sensor: "mixtank", ref_sensor: "display_tank",
    heat_sw: "mixtank_heater",
    air_sw: "mixtank_air",
    air_run_ms: 4 * 60 * 60 * 1000, air_idle_ms: 5 * 60 * 1000,
    pump_sw: "mixtank_pump",
    pump_run_ms: 4 * 60 * 60 * 1000, pump_idle_ms: 5 * 60 * 1000,
    state_at: Timex.now()}]
end

def seed([]), do: []
def seed(%{__struct__: type, name: name} = thing) do
  Logger.info "seeding #{type} #{name}"
  Repo.insert(thing)
end

def seed([thing | list]) do

  [seed(thing)] ++ seed(list)
end

def seed_mixtank([]), do: []
def seed_mixtank(%Mixtank{} = m) do
  Logger.info fn -> "seeding mixtank #{m.name}" end
  Mixtank.add(m)
end

def seed_mixtank([m | rest]) do
  [seed_mixtank(m)] ++ seed_mixtank(rest)
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
