defmodule Mcp.Sensor do
@moduledoc """
  The Sensor module provides the base of a sensor reading.
"""

alias __MODULE__

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

import Application, only: [get_env: 2]
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2, where: 3]
import Mcp.Repo, only: [insert!: 1, update!: 1, query: 1,
                        transaction: 1, one: 1]
import Mcp.DevAlias, only: [friendly_name: 1]

alias Mcp.SensorTemperature
alias Mcp.SensorRelHum

alias Timeseries.Temperature
alias Timeseries.Influx
alias Timeseries.RelHum

schema "sensor" do
  field :device, :string
  field :sensor_type, :string
  field :dt_reading, Timex.Ecto.DateTime
  field :dt_last_seen, Timex.Ecto.DateTime
  has_one :temperature, Mcp.SensorTemperature
  has_one :relhum, Mcp.SensorRelHum

  timestamps usec: true
end

def external_update(r)
when is_map(r) do
  fname = friendly_name(r.device)
  s = get_by_device_name(r.device, r.type) |> update_sensor_values(r)

  case s.sensor_type do
    "temp"   -> tf = s.temperature.tf
                tf = Float.to_string(tf) |> String.pad_leading(8)

                tc = s.temperature.tc
                tc = Float.to_string(tc) |> String.pad_leading(8)

                t = %Temperature{}
                t = %{t | fields: %{t.fields | val: s.temperature.tf}}
                t = %{t | tags: %{t.tags | remote_host: r.host}}
                t = %{t | tags: %{t.tags | device: r.device}}
                t = %{t | tags: %{t.tags | friendly_name: fname}}
                t = %{t | timestamp: r.mtime}

                Influx.write(t, [precision: :seconds])

                Logger.debug fn -> ~s/#{fname} #{tf}F #{tc}C/ end
    "relhum" -> tf = s.temperature.tf
                tf = Float.to_string(tf) |> String.pad_leading(8)

                tc = s.temperature.tc
                tc = Float.to_string(tc) |> String.pad_leading(8)

                rh = s.relhum.rh
                rh = Float.to_string(rh) |> String.pad_leading(8)

                t = %Temperature{}
                t = %{t | fields: %{t.fields | val: s.temperature.tf}}
                t = %{t | tags: %{t.tags | remote_host: r.host}}
                t = %{t | tags: %{t.tags | device: r.device}}
                t = %{t | tags: %{t.tags | friendly_name: fname}}
                t = %{t | timestamp: r.mtime}

                Influx.write(t, [precision: :seconds])

                rh = %RelHum{}
                rh = %{rh | fields: %{rh.fields | val: s.relhum.rh}}
                rh = %{rh | tags: %{rh.tags | remote_host: r.host}}
                rh = %{rh | tags: %{rh.tags | device: r.device}}
                rh = %{rh | tags: %{rh.tags | friendly_name: fname}}
                rh = %{rh | timestamp: r.mtime}

                Influx.write(rh, [precision: :seconds])

                Logger.debug fn -> ~s/#{fname} #{tf}F #{tc}C #{rh}RH/ end
  end

  s
end

# here we actuall create a new sensor with a temperature reading
# and persist it to the database
defp create_if_does_not_exist(:nil, device, "relhum" = type) do
  r = %SensorRelHum{}
  t = %SensorTemperature{}
  s = %Sensor{device: device, sensor_type: type,
              dt_last_seen: Timex.now(), relhum: r, temperature: t}

  insert!(s)
end

defp create_if_does_not_exist(:nil, device, "temp" = type) do
  t = %SensorTemperature{}
  s = %Sensor{device: device, sensor_type: type,
              dt_last_seen: Timex.now(), temperature: t}

  insert!(s)
end

# here we handle if the sensor already exists
defp create_if_does_not_exist(%Sensor{} = s, _fname, _type), do: s

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
  scs = change(sensor, dt_reading: dt_reported, dt_last_seen: dt_reported)
  update!(scs)

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
