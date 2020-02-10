defmodule Reef do
  @moduledoc false

  require Logger
  import IO.ANSI

  alias Dutycycle.Profile, as: DCP
  alias Dutycycle.Server, as: DCS
  alias Thermostat.Profile, as: THP
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
  end

  def display_tank_pause, do: ths_standby(dt())
  def display_tank_resume, do: ths_activate(dt(), "75F")

  def dcs_resume(dc) when is_binary(dc), do: DCS.resume(dc)
  def dcs_standby(dc) when is_binary(dc), do: DCS.standby(dc)

  def halt(name) when is_binary(name), do: DCS.halt(name)

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

  def mix_air_pause, do: DCS.halt(rma())
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

  def mix_pump_pause, do: DCS.halt(rmp())
  def mix_pump_resume, do: DCS.resume(rmp())

  def mix_rodi_fast, do: DCS.activate_profile(rmrf(), "fast")
  def mix_rodi_halt, do: DCS.halt(rmrf())

  def mix_standby,
    do: [
      {rma(), rma() |> DCS.standby()},
      {rmp(), rmp() |> DCS.standby()},
      {swmt(), swmt() |> THS.standby()}
    ]

  def resume(name) when is_binary(name), do: DCS.resume(name)
  def resume_ato, do: DCS.resume(ato())
  def resume_air, do: DCS.resume(rma())
  def resume_pump, do: DCS.resume(rmp())

  def status do
    opts = [active: true]

    IO.puts(clear())
    print_heading("Reef Subsystem Status")

    dcs = for name <- [rmp(), rma(), rmrf(), ato()], do: dc_status(name, opts)
    ths = for name <- [swmt(), display_tank()], do: th_status(name, opts)
    ss = for name <- [dt_sensor()], do: sensor_status(name)

    all = dcs ++ ths ++ ss

    Scribe.print(all,
      data: [
        {"Subsystem", :subsystem},
        {"Status", :status},
        {"Active", :active}
      ]
    )
    |> IO.puts()
  end

  def halt_ato, do: DCS.halt(ato())
  def halt_air, do: DCS.halt(rma())
  def halt_pump, do: DCS.halt(rmp())

  def ths_activate(th, profile)
      when is_binary(th) and is_binary(profile),
      do: THS.activate_profile(th, profile)

  def ths_standby(th) when is_binary(th), do: THS.standby(th)

  def ths_standby(th) when is_binary(th), do: THS.standby(th)

  def utility_pump(p) when is_binary(p),
    do: DCS.activate_profile(rmp(), p)

  def utility_pump(_), do: print_usage("utility_pump", "profile")

  def utility_pump_off, do: rmp() |> DCS.activate_profile(standby())

  def water_change_begin,
    do: [
      {rmp(), rmp() |> DCS.halt()},
      {rma(), rma() |> DCS.halt()},
      {ato(), ato() |> DCS.halt()},
      {swmt(), swmt() |> THS.activate_profile(standby())},
      {display_tank(), display_tank() |> THS.activate_profile(standby())}
    ]

  def water_change_end do
    a = rmp() |> DCS.halt()
    b = rma() |> DCS.halt()
    c = ato() |> DCS.resume()
    d = swmt() |> THS.activate_profile(standby())
    e = display_tank() |> THS.activate_profile("75F")

    [{rmp(), a}, {rma(), b}, {ato(), c}, {swmt(), d}, {display_tank(), e}]
  end

  def xfer_swmt_to_wst, do: {rmp(), DCS.activate_profile(rmp(), "mx to wst")}
  def xfer_wst_to_sewer, do: {rmp(), DCS.activate_profile(rmp(), "drain wst")}

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

  defp dc_status(name, opts),
    do: %{
      subsystem: name,
      status: DCS.profiles(name, opts) |> DCP.name(),
      active: DCS.active?(name)
    }

  defp sensor_status(name) do
    temp_format = fn sensor ->
      temp = Sensor.fahrenheit(name: sensor, since_secs: 30)
      if is_nil(temp), do: temp, else: Float.round(temp, 1)
    end

    %{
      subsystem: name,
      status: temp_format.(name),
      active: "n/a"
    }
  end

  defp th_status(name, opts),
    do: %{
      subsystem: name,
      status: THS.profiles(name, opts) |> THP.name(),
      active: "n/a"
    }

  # constants
  defp add_salt, do: "add salt"
  defp ato, do: "display tank ato"
  defp display_tank, do: "display tank"
  defp dt, do: display_tank()
  defp dt_sensor, do: "display_tank"
  defp rmrf, do: "mix rodi"
  defp rma, do: "mix air"
  defp rmp, do: "mix pump"
  defp standby, do: "standby"
  defp swmt, do: "mix tank"
end
