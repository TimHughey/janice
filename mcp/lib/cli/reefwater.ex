defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  alias Dutycycle.Profile, as: DCP
  alias Dutycycle.Server, as: DCS
  alias Thermostat.Server, as: THS

  def help do
    IO.puts(clear())
    IO.puts(yellow() <> underline() <> "Reef Control CLI" <> reset())
    IO.puts(" ")

    [
      %{cmd: "dcs_standby()", desc: "set Dutycycle to standby"},
      %{cmd: "ths_standby()", desc: "set Thermostat to standby"},
      %{cmd: "mix_air(profile)", desc: "set mix air profile"}
    ]
    |> Scribe.print(style: Scribe.Style.NoBorder)
    |> IO.puts()

    # print_mix("mix_air(profile) -> control reefwater mix air")
    # print_mix("mix_heat(:standby | profile ) -> control reefwater mix heat")
    # print_mix("mix_keep_fresh() -> set mix air and pump to keep water fresh")
    # print_mix("utility_pump(profile) -> control utility pump")
    # print_mix("utility_pump_off() -> switch off utility pump")
    # IO.puts(" ")
    #
    # print_water("water_change_begin() -> setup for water change")
    # print_water("water_change_end() -> stop everything after water change")
    # IO.puts(" ")
  end

  def display_tank_pause, do: ths_standby(dt())
  def display_tank_resume, do: ths_activate(dt(), "75F")

  def dcs_standby(dc) when is_binary(dc), do: DCS.standby(dc)

  def heat_standby,
    do: [
      {swmt(), swmt() |> THS.activate_profile(standby())},
      {dt(), dt() |> THS.activate_profile(standby())}
    ]

  def keep_fresh,
    do: [
      {rmp(), DCS.activate_profile(rmp(), "keep fresh")},
      {rma(), DCS.activate_profile(rma(), "keep fresh")}
    ]

  def mix_add_salt do
    rmp() |> DCS.activate_profile(add_salt())
    rma() |> DCS.activate_profile(add_salt())
    swmt() |> THS.activate_profile(standby())
  end

  def mix_air(profile) when is_binary(profile) do
    DCS.activate_profile(rma(), profile)
  end

  def mix_air(_), do: print_usage("mix_air", "profile)")

  def mix_air_pause, do: DCS.stop(rma())
  def mix_air_resume, do: DCS.resume(rma())

  def mix_heat_standby, do: THS.activate_profile(swmt(), standby())

  def mix_heat(p) when is_binary(p), do: THS.activate_profile(swmt(), p)

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

  def mix_pump_pause, do: DCS.stop(rmp())
  def mix_pump_resume, do: DCS.resume(rmp())

  def mix_rodi_fast, do: DCS.activate_profile(rmrf(), "fast")
  def mix_rodi_stop, do: DCS.stop(rmrf())

  def mix_standby,
    do: [
      {rma(), rma() |> DCS.standby()},
      {rmp(), rmp() |> DCS.standby()},
      {swmt(), swmt() |> THS.standby()}
    ]

  def resume(name) when is_binary(name), do: DCS.resume(name)
  def resume_air, do: DCS.resume(rma())
  def resume_pump, do: DCS.resume(rmp())

  def status do
    opts = [active: true]

    temp_format = fn sensor ->
      temp = Sensor.fahrenheit(name: sensor, since_secs: 30)
      if is_nil(temp), do: temp, else: Float.round(temp, 1)
    end

    IO.puts(clear())
    print_heading("Reef Subsystem Status")

    [
      %{subsystem: rmp(), status: rmp() |> DCS.profiles(opts) |> DCP.name()},
      %{subsystem: rma(), status: rma() |> DCS.profiles(opts) |> DCP.name()},
      %{subsystem: rmrf(), status: rmrf() |> DCS.profiles(opts) |> DCP.name()},
      %{subsystem: swmt(), status: swmt() |> THS.profiles(opts)},
      %{
        subsystem: display_tank(),
        status: display_tank() |> THS.profiles(opts)
      },
      %{
        subsystem: dt_sensor(),
        status: temp_format.(dt_sensor())
      }
    ]
    |> Scribe.print(data: [{"Subsystem", :subsystem}, {"Status", :status}])
    |> IO.puts()
  end

  def stop(name) when is_binary(name), do: DCS.stop(name)
  def stop_air, do: DCS.stop(rma())
  def stop_pump, do: DCS.stop(rmp())

  def ths_activate(th, profile)
      when is_binary(th) and is_binary(profile),
      do: THS.activate_profile(th, profile)

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

  defp print_heading(text) when is_binary(text) do
    IO.puts(" ")
    IO.puts(light_yellow() <> underline() <> text <> reset())
    IO.puts(" ")
  end

  defp print_usage(f, p),
    do:
      IO.puts(
        light_green() <>
          "USAGE: " <>
          light_blue() <>
          f <> "(" <> yellow() <> p <> light_blue() <> ")" <> reset()
      )

  defp add_salt, do: "add salt"
  defp constant, do: "constant"
  defp display_tank, do: "display tank"
  defp dt, do: display_tank()
  defp dt_sensor, do: "display_tank"
  defp rmrf, do: "mix rodi"
  defp rma, do: "mix air"
  defp rmp, do: "mix pump"
  defp standby, do: "standby"
  defp swmt, do: "mix tank"
end
