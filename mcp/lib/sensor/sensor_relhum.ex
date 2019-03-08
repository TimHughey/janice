defmodule SensorRelHum do
  @moduledoc """
    The SensorTemperature module provides individual temperature readings for
    a Sensor
  """

  require Logger
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Repo, only: [delete_all: 2]

  alias Janice.TimeSupport

  schema "sensor_relhum" do
    field(:rh, :float)
    field(:ttl_ms, :integer)
    belongs_to(:sensor, Sensor)

    timestamps()
  end

  # 15 minutes (as milliseconds)
  @delete_timeout_ms 15 * 60 * 1000

  def purge_readings([days: days] = opts) when days <= -30 do
    before = TimeSupport.utc_now() |> Timex.shift(opts)

    from(sr in SensorRelHum, where: sr.inserted_at < ^before)
    |> delete_all(timeout: @delete_timeout_ms)
  end

  def purge_readings(_) do
    IO.puts("Usage:")
    IO.puts("\tSensorRelHum.purge_readings(days: <val <= 30>)")
  end
end
