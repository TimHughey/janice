defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  @rma "reefwater mix air"
  @swmh "salt water mix heat"
  @rmp "reefwater mix pump"

  def help do
    IO.puts(yellow() <> "Reef Control CLI" <> reset())

    IO.puts("mix_air(profile) -> control reefwater mix air")
    IO.puts("mix_heat(:standby | profile ) -> control reefwater mix heat")
    IO.puts("utility_pump(profile) -> control utility pump")
    IO.puts("utilitu_pump_off() -> switch off utility pump")
  end

  def mix_air(profile) when is_binary(profile) do
    Dutycycle.Server.activate_profile(@rma, profile)
  end

  def mix_air(_) do
    IO.puts("mix_air(profile)")
  end

  def mix_heat(:standby) do
    Thermostat.Server.activate_profile(@swmh, "standby")
  end

  def mix_heat(profile) when is_binary(profile) do
    Thermostat.Server.activate_profile(@swmh, "standby")
  end

  def mix_heat(_) do
    IO.puts("mix_heat(:standby | profile)")
  end

  def utility_pump(profile) when is_binary(profile) do
    Dutycycle.Server.activate_profile(@rmp, profile)
  end

  def utility_pump(_) do
    IO.puts("utility_pump(profile)")
  end

  def utility_pump_off do
    Dutycycle.Server.activate_profile(@rmp, "standby")
  end
end
