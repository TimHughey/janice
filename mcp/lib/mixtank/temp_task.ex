defmodule Mixtank.TempTask do
  @moduledoc """

  """

  require Logger
  use Timex

  # NOTE: main entry point for the task
  def run(%Mixtank{name: _name} = mt, opts \\ []) when is_list(opts) do
    Dutycycle.Server.enable(mt.heater)

    control_temp(mt, opts)
  end

  defp control_temp(%Mixtank{} = mt, opts) do
    force = Keyword.get(opts, :force, false)
    profile = mt.profiles |> hd()

    mix_temp = Sensor.fahrenheit(name: mt.sensor, since_secs: 90)
    ref_temp = Sensor.fahrenheit(name: mt.ref_sensor)
    curr_state = if Dutycycle.Server.switch_state(mt.heater), do: "on", else: "off"

    next_state = next_temp_state(mix_temp, ref_temp, profile.temp_diff)

    cond do
      # if force option is set then always set the state
      force ->
        Dutycycle.Server.activate_profile(mt.heater, next_state)

      # prevent unncessary state changes when the state isn't different
      next_state == curr_state ->
        :ok

      # if none of the above match then always set to next_state
      true ->
        Dutycycle.Server.activate_profile(mt.heater, next_state)
    end
  end

  defp next_temp_state(val, ref_val, temp_diff)
       when is_number(val) and is_number(ref_val) and is_number(temp_diff) do
    ref_val = ref_val + temp_diff

    cond do
      val > ref_val + 0.6 -> "off"
      val < ref_val - 0.4 -> "on"
      true -> "on"
    end
  end

  defp next_temp_state(val, ref_val, _temp_diff) do
    if is_nil(val), do: Logger.warn(fn -> "val is nil" end)
    if is_nil(ref_val), do: Logger.warn(fn -> "ref val is nil" end)
    "off"
  end
end
