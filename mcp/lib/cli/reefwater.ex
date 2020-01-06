defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  alias Dutycycle.Server, as: DCS
  alias Thermostat.Server, as: THS

  @rma "reefwater mix air"
  @swmt "salt water mix tank"
  @rmp "reefwater mix pump"

  def help do
    IO.puts(yellow() <> "Reef Control CLI" <> reset())

    IO.puts("mix_air(profile) -> control reefwater mix air")
    IO.puts("mix_heat(:standby | profile ) -> control reefwater mix heat")
    IO.puts("utility_pump(profile) -> control utility pump")
    IO.puts("utility_pump_off() -> switch off utility pump")
  end

  def dcs_standby(dc) when is_binary(dc), do: DCS.standby(dc)

  def mix_air(profile) when is_binary(profile) do
    DCS.activate_profile(@rma, profile)
  end

  def mix_air(_) do
    IO.puts("mix_air(profile)")
  end

  def mix_heat(:standby) do
    THS.activate_profile(@swmt, "standby")
  end

  def mix_heat(profile) when is_binary(profile) do
    THS.activate_profile(@swmt, "standby")
  end

  def mix_heat(_) do
    IO.puts("mix_heat(:standby | profile)")
  end

  def mix_standby do
    DCS.standby(@rma)
    DCS.standby(@rmp)
    THS.standby(@swmt)
    :ok
  end

  def ths_standby(th) when is_binary(th), do: THS.standby(th)

  def utility_pump(profile) when is_binary(profile) do
    DCS.activate_profile(@rmp, profile)
  end

  def utility_pump(_) do
    IO.puts("utility_pump(profile)")
  end

  def utility_pump_off do
    DCS.activate_profile(@rmp, "standby")
  end
end
