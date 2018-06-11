defmodule Thermostat.Control do
  @moduledoc """

  """

  require Logger

  alias Thermostat.Profile

  def current_val(%Thermostat{sensor: sensor}) do
    Sensor.celsius(name: sensor, since_secs: 15)
  end

  def next_state(%{low_offset: low_offset, high_offset: high_offset}, set_pt, val) do
    cond do
      # handle the case where the sensor doesn't have a value
      is_nil(val) or is_nil(set_pt) ->
        "off"

      val >= set_pt + high_offset ->
        "off"

      val <= set_pt + low_offset ->
        "on"

      true ->
        "on"
    end
  end

  def next_state(%{}, set_pt, val) do
    next_state(%{low_offset: 0.0, high_offset: 0.0}, set_pt, val)
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

    next_state = next_state(profile, set_pt, curr_val)

    if next_state === Thermostat.state(t) do
      # handle no change in state
      {:ok, t}
    else
      pos = if next_state === "on", do: true, else: false
      SwitchState.state(Thermostat.switch(t), position: pos)
      Thermostat.state(t, next_state)
    end
  end

  def stop(%Thermostat{} = t) do
    SwitchState.state(Thermostat.switch(t), position: false)
    Thermostat.state(t, "off")
  end
end
