defmodule Janice.Jobs do
  @moduledoc false
  require Logger

  def flush do
    thermo = "grow heat"
    profile = "flush"

    if Thermostat.Server.profiles(thermo, active: true) === profile do
      true
    else
      Logger.info(fn ->
        "thermostat #{inspect(thermo)} set to #{inspect(profile)}"
      end)

      Thermostat.Server.activate_profile(thermo, profile)
    end
  end

  def germination(pos) when is_boolean(pos) do
    sw = "germination_heat"
    rc = Switch.position(sw)

    if rc == {:ok, pos} do
      Logger.debug(fn -> "#{sw} position correct" end)
    else
      Switch.position(sw, position: pos)
      Logger.info(fn -> "#{sw} position set to #{inspect(pos)}" end)
    end
  end

  def grow do
    thermo = "grow heat"
    profile = "optimal"

    if Thermostat.Server.profiles(thermo, active: true) === profile do
      true
    else
      Logger.info(fn ->
        "thermostat #{inspect(thermo)} set to #{inspect(profile)}"
      end)

      Thermostat.Server.activate_profile(thermo, profile)
    end
  end

  def purge_readings(opts) when is_list(opts), do: Sensor.purge_readings(opts)

  def switch_control(sw, pos) when is_binary(sw) and is_boolean(pos) do
    curr = Switch.position(sw)

    case curr do
      # switch is not found
      x when is_nil(x) ->
        Logger.warn(fn -> "switch #{sw} does not exist" end)

      # switch is already in desired position, do nothing
      x when x == pos ->
        Logger.debug(fn -> "#{sw} position is correct" end)

      # switch is not in the desired position, set it
      x when x != pos ->
        Switch.position(sw, position: pos)
        Logger.info(fn -> "#{sw} position set to #{inspect(pos)}" end)

      # catch all, log a warning with what is returned
      _ ->
        Logger.warn(fn -> "#{sw} current position is #{inspect(curr)}" end)
    end
  end

  def switch_control(a, b) do
    Logger.warn(fn ->
      "switch_control invalid arguments: #{inspect(a)} #{inspect(b)}"
    end)
  end

  def touch_file do
    System.cmd("touch", ["/tmp/janice-every-minute"])
  end

  def touch_file(filename) when is_binary(filename) do
    System.cmd("touch", [filename])
  end
end
