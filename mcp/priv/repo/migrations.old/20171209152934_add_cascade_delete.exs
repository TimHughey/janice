defmodule Mcp.Repo.Migrations.AddCascadeDelete do
  @moduledoc """
  """
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    sw_cmd_index_col = [:switch_id, :refid, :ack_at, :sent_at]
    sw_cmd_index = index(:switch_cmd, sw_cmd_index_col, unique: true)

    drop_if_exists table(:switch_state)
    drop_if_exists index(:switch_state, [:switch_id])

    drop_if_exists table(:switch_cmd)
    drop_if_exists sw_cmd_index

    drop_if_exists table(:switch)
    drop_if_exists index(:switch, [:device])

    create_if_not_exists table(:switch) do
      add :device, :string, size: 40, null: false
      add :enabled, :boolean, null: false, default: true
      add :dev_latency, :integer, null: true, default: nil
      add :discovered_at, :utc_datetime, default: current_time
      add :last_cmd_at, :utc_datetime, default: before_now
      add :last_seen_at, :utc_datetime, default: current_time

      timestamps()
    end

    create_if_not_exists table(:switch_cmd) do
      add :refid, :string, size: 40, null: false
      add :switch_id,
        references(:switch, on_delete: :delete_all, on_update: :update_all)
      add :acked, :boolean, null: false, default: false
      add :dev_latency, :integer, null: true, default: nil
      add :rt_latency, :integer, null: true, default: nil
      add :sent_at, :utc_datetime, null: false, default: current_time
      add :ack_at, :utc_datetime, null: true, default: nil

      timestamps()
    end

    create_if_not_exists index(:switch, [:device], unique: true)
    create_if_not_exists index(:switch, [:discovered_at])
    create_if_not_exists index(:switch, [:last_seen_at])

    create_if_not_exists sw_cmd_index

    create_if_not_exists table(:switch_state) do
      add :switch_id,
        references(:switch, on_delete: :delete_all, on_update: :update_all)
      add :pio, :integer, null: false, default: 0
      add :state, :boolean, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:switch_state, [:switch_id])

    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    drop_if_exists table(:sensor_temperature)
    drop_if_exists index(:sensor_temperature, [:sensor_id])
    drop_if_exists table(:sensor_relhum)
    drop_if_exists index(:sensor_relhum, [:sensor_id])

    drop_if_exists table(:sensor)
    drop_if_exists index(:sensor, [:device], unique: true)
    drop_if_exists index(:sensor, [:reading_at])
    drop_if_exists index(:sensor, [:last_seen_at])

    create_if_not_exists table(:sensor) do
      add :device, :string, size: 40, null: false
      add :sensor_type, :string, size: 10, null: false, default: "undef"
      add :dev_latency, :float, null: true, default: nil
      add :reading_at, :utc_datetime, default: before_now
      add :last_seen_at, :utc_datetime, default: current_time

      timestamps()
    end

    create_if_not_exists index(:sensor, [:device], unique: true)
    create_if_not_exists index(:sensor, [:reading_at])
    create_if_not_exists index(:sensor, [:last_seen_at])

    create_if_not_exists table(:sensor_temperature) do
      add :sensor_id,
        references(:sensor, on_delete: :delete_all, on_update: :update_all)
      add :tc, :float, null: true, default: nil
      add :tf, :float, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:sensor_temperature, [:sensor_id])

    create_if_not_exists table(:sensor_relhum) do
      add :sensor_id,
        references(:sensor, on_delete: :delete_all, on_update: :update_all)
      add :rh, :float, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:sensor_relhum, [:sensor_id])
  end
end
