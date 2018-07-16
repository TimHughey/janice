defmodule Thermostat.Control do
  @moduledoc false

  require Logger

  alias Thermostat.Profile

  def current_val(%Thermostat{sensor: sensor}) do
    Sensor.celsius(name: sensor, since_secs: 30)
  end

  def next_state(%{low_offset: low_offset, high_offset: high_offset}, state, set_pt, val) do
    cond do
      # handle the case where the sensor doesn't have a value
      is_nil(val) or is_nil(set_pt) or state === "stopped" ->
        "off"

      val > set_pt + high_offset and (state === "on" or state === "started") ->
        "off"

      val < set_pt + low_offset and (state === "off" or state === "started") ->
        "on"

      true ->
        # if none of the above then keep the same state
        # this handles the case when the temperature is between the low / high offsets
        state
    end
  end

  def next_state(%{}, state, set_pt, val) do
    next_state(%{low_offset: 0.0, high_offset: 0.0}, state, set_pt, val)
  end

  def temperature(%Thermostat{name: name, active_profile: profile} = t) when is_nil(profile) do
    Thermostat.log?(t) && Logger.warn(fn -> "active profile is nil for thermostat [#{name}]" end)
    {:nil_active_profile, t}
  end

  def temperature(%Thermostat{name: name, active_profile: "none"} = t) do
    Thermostat.log?(t) &&
      Logger.warn(fn -> "active profile is [none] for thermostat [#{name}]" end)

    {:no_active_profile, t}
  end

  def temperature(%Thermostat{} = t) do
    profile = Profile.active(t)

    curr_val = current_val(t)
    set_pt = Profile.set_point(profile)

    next_state = next_state(profile, Thermostat.state(t), set_pt, curr_val)

    if next_state === Thermostat.state(t) do
      # handle no change in state
      {:ok, t}
    else
      pos = if next_state === "on", do: true, else: false
      Switch.state(Thermostat.switch(t), position: pos, lazy: true)
      Thermostat.state(t, next_state)
    end
  end

  def stop(%Thermostat{} = t) do
    Switch.state(Thermostat.switch(t), position: false, lazy: true, ack: false)
    Thermostat.state(t, "off")
  end
end
