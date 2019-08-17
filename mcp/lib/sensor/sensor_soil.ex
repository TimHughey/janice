defmodule SensorSoil do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Repo, only: [delete_all: 2]

  alias Janice.TimeSupport

  schema "sensor_soil" do
    field(:moisture, :integer)
    field(:ttl_ms, :integer)
    belongs_to(:sensor, Sensor)

    timestamps()
  end

  # 15 minutes (as milliseconds)
  @delete_timeout_ms 15 * 60 * 1000

  def purge_readings([days: days] = opts) when days < 0 do
    before = TimeSupport.utc_now() |> Timex.shift(opts)

    from(st in SensorSoil, where: st.inserted_at < ^before)
    |> delete_all(timeout: @delete_timeout_ms)
  end
end
