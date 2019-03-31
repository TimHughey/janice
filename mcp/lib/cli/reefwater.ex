defmodule Reef do
  require Logger
  import IO.ANSI

  def help do
    IO.puts("mix(:atom) -> control reefwater mix system")
    IO.puts("sump(:atom)-> control display tank replenish")
    IO.puts(" ")
    IO.puts(yellow() <> ":help displays the various options for each" <> reset())
  end

  def mix(:help) do
    IO.puts(":standby        -> all subsystems on standby\n")

    IO.puts(":standby_mix    -> pump=standby, replenish=fast, fill=standby, heat=standby\n")

    IO.puts(":change         -> pump=on, replenish=off, fill=off, heat=match\n")

    IO.puts(":mix            -> pump=high, replenish=fast, fill=off, heat=match\n")

    IO.puts(":stir           -> pump=low stir, replenish=fast, fill=off, heat=match\n")

    IO.puts(":fill_daytime   -> pump=low, replenish=slow, fill=slow, heat=match\n")

    IO.puts(":fill_overnight -> pump=low, replenish=slow, fill=fast, heat=match\n")

    :ok = IO.puts(":eco            -> pump=low, replenish=fast, fill=standby, heat=low\n")
  end

  def mix(:change) do
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

  def mix(:mix) do
    dcs = [
      {"reefwater mix pump", "slow stir"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def mix(:stir) do
    dcs = [
      {"reefwater mix pump", "30sx5m"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "off"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def mix(:fill_daytime) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "slow"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def mix(:fill_overnight) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "fast"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def mix(:eco) do
    dcs = [
      {"reefwater mix pump", "low"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "low energy")
  end

  def mix(:standby) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "standby"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:standby_mix) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(_anything), do: mix(:help)

  def mix do
    mix(:help)
  end

  def sump(:help) do
    IO.puts(":standby -> replenish=standby")
    IO.puts(":resume  -> replenish=fast")
  end

  def sump(:resume) do
    Dutycycle.Server.activate_profile("display tank replenish", "fast")
  end

  def sump(:standby) do
    Dutycycle.Server.activate_profile("display tank replenish", "standby")
  end

  def sump(:toggle) do
    curr = Dutycycle.Server.profiles("display tank replenish", only_active: true)
    next = sump_next(curr)

    with :ok <- Dutycycle.Server.activate_profile("display tank replenish", next) do
      _discard = IO.puts("sump toggled:  #{curr} --> #{next}")
    else
      err ->
        _discard = IO.puts("toggle failed! #{inspect(err)}")
    end
  end

  def sump_next("standby"), do: "fast"
  def sump_next("fast"), do: "standby"
  def sump_next(_anything), do: "standby"
end
