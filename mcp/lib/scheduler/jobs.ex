defmodule Janice.Jobs do
  @moduledoc false
  require Logger
  import IO.ANSI

  def flush do
    thermo = "grow heat"
    profile = "flush"

    if Thermostat.Server.profiles(thermo, active: true) === profile do
      true
    else
      Logger.info(fn -> "thermostat #{inspect(thermo)} set to #{inspect(profile)}" end)
      Thermostat.Server.activate_profile(thermo, profile)
    end
  end

  def germination(pos) when is_boolean(pos) do
    sw = "germination_heat"
    curr = Switch.state(sw)

    if curr == pos do
      Logger.debug(fn -> "#{sw} position correct" end)
    else
      Switch.state(sw, position: pos, lazy: true)
      Logger.info(fn -> "#{sw} position set to #{inspect(pos)}" end)
    end
  end

  def grow do
    thermo = "grow heat"
    profile = "optimal"

    if Thermostat.Server.profiles(thermo, active: true) === profile do
      true
    else
      Logger.info(fn -> "thermostat #{inspect(thermo)} set to #{inspect(profile)}" end)
      Thermostat.Server.activate_profile(thermo, profile)
    end
  end

  def help do
    IO.puts("reefwater(:atom) -> control reefwater mix system")
    IO.puts("sump(:atom)      -> control display tank replenish")
    IO.puts(" ")
    IO.puts(yellow() <> ":help displays the various options for each" <> reset())
  end

  def reefwater(:help) do
    IO.puts(":standby        -> all subsystems on standby\n")

    IO.puts(":standby_mix    -> pump=standby, replenish=fast, fill=standby, heat=standby\n")

    IO.puts(":change         -> pump=on, replenish=off, fill=off, heat=match\n")

    IO.puts(":mix            -> pump=high, replenish=fast, fill=off, heat=match\n")

    IO.puts(":stir           -> pump=low stir, replenish=fast, fill=off, heat=match\n")

    IO.puts(":fill_daytime   -> pump=low, replenish=slow, fill=slow, heat=match\n")

    IO.puts(":fill_overnight -> pump=low, replenish=slow, fill=fast, heat=match\n")

    :ok = IO.puts(":eco            -> pump=low, replenish=fast, fill=standby, heat=low\n")
  end

  def reefwater(:change) do
    dcs = [
      {"reefwater mix pump", "on"},
      {"display tank replenish", "off"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs do
      Dutycycle.Server.activate_profile(dc, p, enable: true)
    end

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:mix) do
    dcs = [
      {"reefwater mix pump", "slow stir"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:stir) do
    dcs = [
      {"reefwater mix pump", "30sx5m"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:fill_daytime) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "slow"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:fill_overnight) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "fast"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:eco) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "low energy")
  end

  def reefwater(:standby) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "standby"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def reefwater(:standby_mix) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def sump(:help) do
    IO.puts(":standby -> replenish=standby")
    IO.puts(":resume  -> replenish=fast")
  end

  def sump(:standby) do
    Dutycycle.Server.activate_profile("display tank replenish", "standby")
  end

  def sump(:resume) do
    Dutycycle.Server.activate_profile("display tank replenish", "fast")
  end

  def switch_control(sw, pos) when is_binary(sw) and is_boolean(pos) do
    curr = Switch.state(sw)

    case curr do
      # switch is not found
      x when is_nil(x) ->
        Logger.warn(fn -> "switch #{sw} does not exist" end)

      # switch is already in desired position, do nothing
      x when x == pos ->
        Logger.debug(fn -> "#{sw} position is correct" end)

      # switch is not in the desired position, set it
      x when x != pos ->
        Switch.state(sw, position: pos, lazy: true)
        Logger.info(fn -> "#{sw} position set to #{inspect(pos)}" end)

      # catch all, log a warning with what is returned
      _ ->
        Logger.warn(fn -> "#{sw} current position is #{inspect(curr)}" end)
    end
  end

  def switch_control(a, b) do
    Logger.warn(fn -> "switch_control invalid arguments: #{inspect(a)} #{inspect(b)}" end)
  end

  def touch_file do
    System.cmd("touch", ["/tmp/janice-every-minute"])
  end

  def touch_file(filename) when is_binary(filename) do
    System.cmd("touch", [filename])
  end
end
