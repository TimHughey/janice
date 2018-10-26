defmodule SensorTemperature do
  @moduledoc """
    The SensorTemperature module provides individual temperature readings for
    a Sensor
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Repo, only: [delete_all: 2]

  schema "sensor_temperature" do
    field(:tc, :float)
    field(:tf, :float)
    field(:ttl_ms, :integer)
    belongs_to(:sensor, Sensor)

    timestamps(usec: true)
  end

  def purge_readings(unit: num) when is_list(opts) do
    before = Timex.now() |> Timex.shift(opts)

    res = from(st in SensorTemperature, where: st.inserted_at <= before) |> delete_all()
  end
end
