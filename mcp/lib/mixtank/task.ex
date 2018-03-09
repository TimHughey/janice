defmodule Mixtank.TankTask do
  @moduledoc """
  """
  require Logger
  use Timex
  use Task

  alias Mixtank.State

  def run(%Mixtank{name: name} = mt, opts) do
    active = mt.profiles |> hd()
    cycles = [:pump, :air, :fill, :replenish]

    _res =
      for c <- cycles do
        name = Map.get(mt, c)
        p = Map.get(active, c)
        Dutycycle.Server.activate_profile(name, p, enable: true)
      end

    # only enable heater, it's profile is managed by the control temp loop
    Dutycycle.Server.enable(mt.heater)

    State.set_started(mt)

    Logger.info(fn -> "[#{name}] started with profile [#{active.name}]" end)

    loop(mt, opts)
  end

  defp loop(%Mixtank{} = mt, opts) do
    control_temp(mt, opts)

    :timer.sleep(opts.control_temp_secs * 1000)
    loop(mt, opts)
  end

  defp control_temp(%Mixtank{} = mt, _opts) do
    profile = mt.profiles |> hd()

    mix_temp = Sensor.fahrenheit(name: mt.sensor, since_secs: 90)
    ref_temp = Sensor.fahrenheit(name: mt.ref_sensor)
    curr_state = Dutycycle.Server.switch_state(mt.heater)

    next_state = next_temp_state(mix_temp, ref_temp, curr_state, profile.temp_diff)

    cond do
      is_nil(next_state) -> nil
      next_state -> Dutycycle.Server.activate_profile(mt.heater, "on")
      not next_state -> Dutycycle.Server.activate_profile(mt.heater, "off")
    end
  end

  defp next_temp_state(val, ref_val, curr_state, temp_diff)
       when is_float(val) and is_float(ref_val) and is_boolean(curr_state) do
    ref_val = ref_val + temp_diff

    next_state =
      cond do
        is_nil(val) or is_nil(ref_val) -> false
        val > ref_val + 0.5 -> false
        val < ref_val - 0.1 -> true
        true -> curr_state
      end

    if curr_state == next_state, do: nil, else: next_state
  end

  defp next_temp_state(_val, _ref_val, curr_state, _temp_diff), do: curr_state
end
