defmodule Mcp.Repo.Migrations.AddSensors do
  @moduledoc """
  """
  use Ecto.Migration

  def change do

    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    drop_if_exists table(:sensor)
    drop_if_exists index(:sensor, [:device], unique: true)
    drop_if_exists index(:sensor, [:dt_reading])
    drop_if_exists index(:sensor, [:dt_last_seen])

    create_if_not_exists table(:sensor) do
      add :device, :string, size: 40, null: false
      add :sensor_type, :string, size: 10, null: false, default: "undef"
      add :dev_latency, :float, null: true, default: nil
      add :dt_reading, :utc_datetime, default: before_now
      add :dt_last_seen, :utc_datetime, default: current_time

      timestamps()
    end

    create_if_not_exists index(:sensor, [:device], unique: true)
    create_if_not_exists index(:sensor, [:dt_reading])
    create_if_not_exists index(:sensor, [:dt_last_seen])

    ##
    ## SensorTemperature
    ##

    drop_if_exists table(:sensor_temperature)
    drop_if_exists index(:sensor_temperature, [:sensor_id])

    create_if_not_exists table(:sensor_temperature) do
      add :sensor_id, references(:sensor)
      add :tc, :float, null: true, default: nil
      add :tf, :float, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:sensor_temperature, [:sensor_id])

    ##
    ## SensorRelHum
    ##

    drop_if_exists table(:sensor_relhum)
    drop_if_exists index(:sensor_relhum, [:sensor_id])

    create_if_not_exists table(:sensor_relhum) do
      add :sensor_id, references(:sensor)
      add :rh, :float, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:sensor_relhum, [:sensor_id])

  end

end
