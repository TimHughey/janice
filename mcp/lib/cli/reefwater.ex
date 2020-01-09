defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  alias Dutycycle.Server, as: DCS
  alias Thermostat.Server, as: THS

  def help do
    IO.puts(clear())
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
    IO.puts(" ")
  end

  def dcs_standby(dc) when is_binary(dc), do: DCS.standby(dc)

  def mix_add_salt do
    rmp() |> DCS.activate_profile(add_salt())
    rma() |> DCS.activate_profile(add_salt())
    swmt() |> THS.activate_profile(standby())
  end

  def mix_air(profile) when is_binary(profile) do
    DCS.activate_profile(rma(), profile)
  end

  def mix_air(_), do: print_usage("mix_air", "profile)")

  def mix_heat_standby, do: THS.activate_profile(swmt(), standby())

  def mix_heat(profile) when is_binary(profile) do
    THS.activate_profile(swmt(), standby())
  end

  def mix_heat(_), do: print_usage("mix_heat", "profile")

  def mix_match_display_tank do
    THS.activate_profile(swmt(), "prep for change")
    DCS.activate_profile(rma(), "keep fresh")
    DCS.activate_profile(rmp(), "eco")
    :ok
  end

  def mix_pump(p) when is_binary(p), do: utility_pump(p)
  def mix_pump(_), do: print_usage("mix_pump", "profile")
  def mix_pump_off, do: utility_pump_off()

  def mix_standby,
    do: [
      {rma(), rma() |> DCS.standby()},
      {rmp(), rmp() |> DCS.standby()},
      {swmt(), swmt() |> THS.standby()}
    ]

  def mix_status do
    dcs_opts = [only_active: true]
    ths_opts = [active: true]

    [
      {rmp(), rmp() |> DCS.profiles(dcs_opts)},
      {rma(), rma() |> DCS.profiles(dcs_opts)},
      {swmt(), swmt() |> THS.profiles(ths_opts)},
      {display_tank(), display_tank() |> THS.profiles(ths_opts)}
    ]
  end

  def ths_standby(th) when is_binary(th), do: THS.standby(th)

  def utility_pump(p) when is_binary(p),
    do: DCS.activate_profile(rmp(), p)

  def utility_pump(_), do: print_usage("utility_pump", "profile")

  def utility_pump_off, do: rmp() |> DCS.activate_profile(standby())

  def water_change_begin,
    do: [
      {rmp(), rmp() |> DCS.activate_profile(constant())},
      {rma(), rma() |> DCS.activate_profile(standby())},
      {swmt(), swmt() |> THS.activate_profile(standby())},
      {display_tank(), display_tank() |> THS.activate_profile(standby())}
    ]

  def water_change_end do
    a = rmp() |> DCS.activate_profile(standby())
    b = rma() |> DCS.activate_profile(standby())
    c = swmt() |> THS.activate_profile(standby())
    d = display_tank() |> THS.activate_profile("75F")

    [{rmp(), a}, {rma(), b}, {swmt(), c}, {display_tank(), d}]
  end

  defp print_mix(text), do: IO.puts(light_blue() <> text <> reset())
  defp print_standby(text), do: IO.puts(cyan() <> text <> reset())

  defp print_usage(f, p),
    do:
      IO.puts(
        light_green() <>
          "USAGE: " <>
          light_blue() <>
          f <> "(" <> yellow() <> p <> light_blue() <> ")" <> reset()
      )

  defp print_water(text), do: IO.puts(light_green() <> text <> reset())

  defp add_salt, do: "add salt"
  defp constant, do: "constant"
  defp display_tank, do: "display tank"
  defp rma, do: "reefwater mix air"
  defp rmp, do: "reefwater mix pump"
  defp standby, do: "standby"
  defp swmt, do: "salt water mix tank"
end
