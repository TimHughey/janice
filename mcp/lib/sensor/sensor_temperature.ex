defmodule SensorTemperature do
  @moduledoc false

  require Logger
  use Ecto.Schema

  # will be used eventually for purge readings
  # import Ecto.Query, only: [from: 2]
  # import Repo, only: [delete_all: 2]

  schema "sensor_temperature" do
    field(:tc, :float)
    field(:tf, :float)
    field(:ttl_ms, :integer)
    belongs_to(:sensor, Sensor)

    timestamps()
  end

  # def purge_readings(opts) when is_list(opts) do
  #   before = TimeSupport.utc_now() |> Timex.shift(opts)
  #
  #   res = from(st in SensorTemperature, where: st.inserted_at <= before) |> delete_all()
  # end
end
