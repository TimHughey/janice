defmodule Mixtank.TankTask do
  @moduledoc """
  """
  require Logger
  use Timex
  use Task

  alias Mixtank.State

  def run(%Mixtank{name: name} = mt, opts) do
    p = mt.profiles |> hd()
    Logger.info fn -> "[#{name}] started with profile [#{p.name}]" end

    :timer.sleep(3000)
    Dutycycle.Control.activate_profile(mt.pump, p.pump, :enable)

    :timer.sleep(2000)
    Dutycycle.Control.activate_profile(mt.air, p.air, :enable)

    :timer.sleep(2000)
    Dutycycle.Control.activate_profile(mt.fill, p.fill, :enable)

    :timer.sleep(2000)
    Dutycycle.Control.activate_profile(mt.replenish, p.replenish, :enable)

    State.set_started(mt)

    loop(mt, opts)
  end

  defp loop(%Mixtank{} = mt, opts) do
    control_temp(mt, opts)

    :timer.sleep(opts.control_temp_secs * 1000)
    loop(mt, opts)
  end

  defp control_temp(%Mixtank{} = mt, _opts) do
    profile = mt.profiles |> hd()

    mix_temp = Sensor.fahrenheit(mt.sensor)
    ref_temp = Sensor.fahrenheit(mt.ref_sensor)
    curr_state = Dutycycle.Control.switch_state(mt.heater)

    next_state =
      next_temp_state(mix_temp, ref_temp, curr_state, profile.temp_diff)

    cond do
      is_nil(next_state) -> nil
      next_state         -> Dutycycle.Control.activate_profile(mt.heater,
                              "on", :enable)
      not next_state     -> Dutycycle.Control.activate_profile(mt.heater,
                              "off", :enable)
    end
  end

  defp next_temp_state(val, ref_val, curr_state, temp_diff)
  when is_float(val) and is_float(ref_val) and is_boolean(curr_state) do
    ref_val = ref_val + temp_diff

    next_state =
      cond do
        val > (ref_val + 0.7)     -> false
        val < (ref_val - 0.7)     -> true
        true                      -> curr_state
      end

    if curr_state == next_state, do: nil, else: next_state
  end

  defp next_temp_state(_val, _ref_val, curr_state, _temp_diff), do: curr_state
end
