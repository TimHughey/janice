defmodule Mcp.Sensor do
@moduledoc """
  The Sensor module provides the base of a sensor reading.
"""

alias __MODULE__

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

#import Application, only: [get_env: 2]
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]
import Mcp.Repo, only: [all: 2, insert!: 1, update!: 1, transaction: 1, one: 1]
import Mcp.DevAlias, only: [friendly_name: 1, get_by_friendly_name: 1]

alias Mcp.DevAlias
alias Mcp.SensorTemperature
alias Mcp.SensorRelHum

alias Fact.Fahrenheit
alias Fact.Celsius
alias Fact.RelativeHumidity

schema "sensor" do
  field :device, :string
  field :sensor_type, :string
  field :reading_at, Timex.Ecto.DateTime
  field :last_seen_at, Timex.Ecto.DateTime
  has_one :temperature, Mcp.SensorTemperature
  has_one :relhum, Mcp.SensorRelHum

  timestamps usec: true
end

def all(:friendly_names) do
  query =
    from(s in Sensor,
      join: dev in DevAlias, on: s.device == dev.device,
      order_by: dev.friendly_name,
      select: dev.friendly_name)

  all(query, timeout: 100)
end

@doc ~S"""
Retrieve the fahrenheit temperature reading of a device using it's friendly
name.  Returns nil if the no friendly name exists.

## Examples:
  iex> Mcp.Sensor.fahrenheit("")
  "relhum"

  iex> Mcp.DevAlias.friendly_name("ds/nodev") |> String.starts_with?("new")
  true
"""
def fahrenheit(fname)
when is_binary(fname) do
  get_by_fname(fname) |> fahrenheit()
end

def fahrenheit(%Sensor{temperature: %SensorTemperature{tf: tf}}), do: tf
def fahrenheit(%Sensor{} = sensor) do
  Logger.warn inspect(sensor)
end

def external_update(r)
when is_map(r) do
  fname = friendly_name(r.device)
  {:ok, s} = transaction fn ->
              get_by_device_name(r.device, r.type) |>
                update_sensor_values(r) end

  case s.sensor_type do
    "temp"   ->
      Logger.debug fn ->
        tf = s.temperature.tf
        tf = Float.to_string(tf) |> String.pad_leading(8)

        tc = s.temperature.tc
        tc = Float.to_string(tc) |> String.pad_leading(8)
        ~s/#{fname} #{tf}F #{tc}C/ end

      Fahrenheit.record(remote_host: r.host, device: r.device,
        friendly_name: fname, mtime: r.mtime, val: s.temperature.tf)

      Celsius.record(remote_host: r.host, device: r.device,
        friendly_name: fname, mtime: r.mtime, val: s.temperature.tc)

    "relhum" ->
      Logger.debug fn ->
        tf = s.temperature.tf
        tf = Float.to_string(tf) |> String.pad_leading(8)

        tc = s.temperature.tc
        tc = Float.to_string(tc) |> String.pad_leading(8)

        rh = s.relhum.rh
        rh = Float.to_string(rh) |> String.pad_leading(8)
        ~s/#{fname} #{tf}F #{tc}C #{rh}RH/ end

      Fahrenheit.record(remote_host: r.host, device: r.device,
        friendly_name: fname, mtime: r.mtime, val: s.temperature.tf)

      Celsius.record(remote_host: r.host, device: r.device,
        friendly_name: fname, mtime: r.mtime, val: s.temperature.tc)

      RelativeHumidity.record(remote_host: r.host, device: r.device,
        friendly_name: fname, mtime: r.mtime, val: s.relhum.rh)
  end
  s
end

def relhum(fname)
when is_binary(fname) do
  get_by_fname(fname) |> relhum()
end

def relhum(%Sensor{relhum: %SensorRelHum{rh: rh}}), do: rh
def relhum(_anything), do: nil

# here we actuall create a new sensor with a temperature reading
# and persist it to the database
defp create_if_does_not_exist(:nil, device, "relhum" = type) do
  r = %SensorRelHum{}
  t = %SensorTemperature{}
  s = %Sensor{device: device, sensor_type: type,
              last_seen_at: Timex.now(), relhum: r, temperature: t}

  insert!(s)
end

defp create_if_does_not_exist(:nil, device, "temp" = type) do
  t = %SensorTemperature{}
  s = %Sensor{device: device, sensor_type: type,
              last_seen_at: Timex.now(), temperature: t}

  insert!(s)
end

# here we handle if the sensor already exists
defp create_if_does_not_exist(%Sensor{} = s, _fname, _type), do: s

defp get_by_device_name(:nil), do: nil
defp get_by_device_name(%DevAlias{device: device}) do
  query =
    from(s in Sensor,
      where: s.device == ^device)

  one(query) |> get_by_device_name()
end

defp get_by_device_name(%Sensor{device: device, sensor_type: temp}) do
  get_by_device_name(device, temp)
end

defp get_by_device_name(device, "relhum" = type)
when is_binary(device) do
  query =
    from(s in Sensor,
      join: t in assoc(s, :temperature),
      join: r in assoc(s, :relhum),
      where: s.device == ^device and s.sensor_type == ^type,
      preload: [temperature: t, relhum: r])

  one(query) |> create_if_does_not_exist(device, type)
end

defp get_by_device_name(device, "temp" = type)
when is_binary(device) do
  query =
    from(s in Sensor,
      join: t in assoc(s, :temperature),
      where: s.device == ^device and s.sensor_type == ^type,
      preload: [temperature: t])

  one(query) |> create_if_does_not_exist(device, type)
end

defp get_by_fname(fname)
when is_binary(fname) do
  get_by_friendly_name(fname) |> get_by_device_name()
end

defp update_sensor_values(%Sensor{sensor_type: "temp"} = sensor, r)
when is_map(r) do
  update_sensor_temperature(sensor, r) |>
    update_sensor_datetimes(r)
end

defp update_sensor_values(%Sensor{sensor_type: "relhum"} = sensor, r)
when is_map(r) do
  update_sensor_temperature(sensor, r) |>
    update_sensor_relhum(r) |>
    update_sensor_datetimes(r)
end

defp update_sensor_datetimes(%Sensor{} = sensor, r)
when is_map(r) do
  dt_reported = Timex.from_unix(r.mtime)
  scs = change(sensor, reading_at: dt_reported, last_seen_at: dt_reported)
  update!(scs)

  DevAlias.just_seen(sensor.device)

  sensor
end

defp update_sensor_relhum(%Sensor{} = sensor, r)
when is_map(r) do
  rh = Float.round(r.rh * 1.0, 2)
  rcs = change(sensor.relhum, %{rh: rh})
  relhum = update!(rcs)

  %{sensor | relhum: relhum}
end

defp update_sensor_temperature(%Sensor{} = sensor, r)
when is_map(r) do
  tc = Float.round(r.tc * 1.0, 2)
  tf = Float.round(r.tf * 1.0, 2)
  tcs = change(sensor.temperature, %{tc: tc, tf: tf})
  temperature = update!(tcs)

  %{sensor | temperature: temperature}
end
end
