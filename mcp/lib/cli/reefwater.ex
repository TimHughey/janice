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
    _discard = fn ->
      IO.puts(":standby        -> all subsystems on standby\n")

      IO.puts(":fill_initial   -> pump=standby, replenish=fast, fill=fast, heat=standby\n")

      IO.puts(":fill_final     -> pump=easy stir, replenish=slow, fill=fast, heat=standby\n")

      IO.puts(":mix            -> pump=constant, replenish=fast, fill=standby, heat=standby\n")

      IO.puts(":change_prep    -> pump=easy stir, replenish=fast, fill=standby, heat=match\n")

      IO.puts(":change         -> pump=on, replenish=standby, fill=standby, heat=standby\n")

      IO.puts(":stir           -> pump=low stir, replenish=fast, fill=standby, heat=standby\n")

      IO.puts(":eco            -> pump=low, replenish=fast, fill=standby, heat=low\n")
    end
  end

  def mix(:standby) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:fill_initial) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "fast"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:fill_final) do
    dcs = [
      {"reefwater mix pump", "easy stir"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "slow"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:mix) do
    dcs = [
      {"reefwater mix pump", "constant"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs, do: Dutycycle.Server.activate_profile(dc, p, enable: true)

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:change_prep) do
    dcs = [
      {"reefwater mix pump", "easy stir"},
      {"display tank replenish", "slow"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs do
      Dutycycle.Server.activate_profile(dc, p, enable: true)
    end

    Thermostat.Server.activate_profile("reefwater mix heat", "match display tank")
  end

  def mix(:change) do
    dcs = [
      {"reefwater mix pump", "standby"},
      {"display tank replenish", "standby"},
      {"reefwater rodi fill", "standby"}
    ]

    for {dc, p} <- dcs do
      Dutycycle.Server.activate_profile(dc, p, enable: true)
    end

    Thermostat.Server.activate_profile("reefwater mix heat", "standby")
  end

  def mix(:stir) do
    dcs = [
      {"reefwater mix pump", "low stir"},
      {"display tank replenish", "fast"},
      {"reefwater rodi fill", "standby"}
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
