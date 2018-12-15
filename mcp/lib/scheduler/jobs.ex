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
    sw = "germination_light"
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
    IO.puts(yellow <> ":help displays the various options for each" <> reset)
  end

  def reefwater(:help) do
    IO.puts(":standby        -> all subsystems on standby")
    IO.puts("                -> heat=low energy")
    IO.puts(":change         -> air=off, pump=on, replenish=off, fill=off")
    IO.puts("                -> heat=match display tank")
    IO.puts(":mix            -> air=off, pump=high, replenish=fast, fill=off")
    IO.puts("                -> heat=match display tank")
    IO.puts(":fill_daytime   -> air=off, pump=low, replenish=slow, fill=slow")
    IO.puts("                -> heat=match display tank")
    IO.puts(":fill_overnight -> air=off, pump=low, replenish=slow, fill=fast")
    IO.puts("                -> heat=match display tank")
    IO.puts(":eco            -> air=off, pump=low, replenish=fast, fill=standby")
    IO.puts("                -> heat=low energy")
  end

  def reefwater(:change) do
    dcs = [
      {"reefwater mix air", "off"},
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
      {"reefwater mix air", "off"},
      {"reefwater mix pump", "high"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:fill_daytime) do
    dcs = [
      {"reefwater mix air", "off"},
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "slow"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:fill_overnight) do
    dcs = [
      {"reefwater mix air", "off"},
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "fast"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def reefwater(:eco) do
    dcs = [
      {"reefwater mix air", "off"},
      {"reefwater mix pump", "low"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "low energy")
  end

  def reefwater(:standby) do
    dcs = [
      {"reefwater mix air", "standby"},
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "standby"},
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

  def touch_file do
    System.cmd("touch", ["/tmp/janice-every-minute"])
  end

  def touch_file(filename) when is_binary(filename) do
    System.cmd("touch", [filename])
  end
end
