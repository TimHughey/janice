defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  alias Dutycycle.Server, as: DCS
  alias Thermostat.Server, as: THS

  @rma "reefwater mix air"
  @swmt "salt water mix tank"
  @rmp "reefwater mix pump"

  @add_salt "add salt"
  @standby "standby"
  @standby "constant"

  def help do
    IO.puts(yellow() <> underline() <> "Reef Control CLI" <> reset())
    IO.puts(" ")

    print_standby("dcs_standby(dutycycle_name)")
    print_standby("ths_standby(thermostat_name)")
    IO.puts(" ")

    print_mix("mix_air(profile) -> control reefwater mix air")
    print_mix("mix_heat(:standby | profile ) -> control reefwater mix heat")
    print_mix("utility_pump(profile) -> control utility pump")
    print_mix("utility_pump_off() -> switch off utility pump")
    IO.puts(" ")

    print_water("water_change_begin() -> setup for water change")
    print_water("water_change_end() -> stop everything after water change")
  end

  def dcs_standby(dc) when is_binary(dc), do: DCS.standby(dc)

  def mix_add_salt do
    DCS.activate_profile(@rmp, @add_salt)
    DCS.activate_profile(@rma, @add_salt)
    THS.activate_profile(@swmt, @standby)
  end

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

  def mix_match_display_tank do
    THS.activate_profile(@swmt, "prep for change")
    DCS.activate_profile(@rma, "keep fresh")
    DCS.activate_profile(@rmp, "eco")
    :ok
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

  def water_change_begin do
    DCS.activate_profile(@rmp, @constant)
    DCS.activate_profile(@rma, @standby)
    THS.activate_profile(@swmt, @standby)
  end

  def water_change_end do
    DCS.activate_profile(@rmp, @standby)
    DCS.activate_profile(@rma, @standby)
    THS.activate_profile(@swmt, @standby)
  end

  def print_mix(text), do: IO.puts(light_blue() <> text <> reset())
  def print_standby(text), do: IO.puts(cyan() <> text <> reset())
  def print_water(text), do: IO.puts(light_green() <> text <> reset())
end
