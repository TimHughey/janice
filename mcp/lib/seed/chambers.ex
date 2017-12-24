defmodule Seed.Chambers do
  @moduledoc """
  """

alias Mcp.Chamber
#alias Mcp.Sensor

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
             warm: true, mist: false, fae: false, stir: true}] end

end
