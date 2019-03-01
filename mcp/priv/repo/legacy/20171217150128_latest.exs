defmodule Repo.Migrations.Latest do
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    drop_if_exists(table(:dev_alias))
    drop_if_exists(index(:dev_alias, [:device]))
    drop_if_exists(index(:dev_alias, [:friendly_name]))

    drop_if_exists(table(:switch_state))
    drop_if_exists(index(:switch_state, [:switch_id]))
    drop_if_exists(index(:switch_state, [:name]))

    drop_if_exists(table(:switch_cmd))
    drop_if_exists(index(:switch_cmd, [:switch_id]))
    drop_if_exists(index(:switch_cmd, [:refid]))
    drop_if_exists(index(:switch_cmd, [:acked]))

    drop_if_exists(table(:switch))
    drop_if_exists(index(:switch, [:device]))

    create_if_not_exists table(:switch) do
      add(:device, :string, size: 40, null: false)
      add(:enabled, :boolean, null: false, default: true)
      add(:dev_latency, :bigint, null: false, default: 0)
      add(:discovered_at, :utc_datetime, default: current_time)
      add(:last_cmd_at, :utc_datetime, default: before_now)
      add(:last_seen_at, :utc_datetime, default: current_time)

      timestamps()
    end

    create_if_not_exists table(:switch_cmd) do
      add(:refid, :string, size: 40, null: false)

      add(
        :switch_id,
        references(:switch, on_delete: :delete_all, on_update: :update_all)
      )

      add(:name, :string, size: 40, null: true)
      add(:acked, :boolean, null: false, default: false)
      add(:rt_latency, :bigint, null: false, default: 0)
      add(:sent_at, :utc_datetime, null: false, default: current_time)
      add(:ack_at, :utc_datetime, null: true, default: nil)

      timestamps()
    end

    create_if_not_exists table(:switch_state) do
      add(
        :switch_id,
        references(:switch, on_delete: :delete_all, on_update: :update_all)
      )

      add(:name, :string, size: 40, null: false)
      add(:description, :text, default: "new switch")
      add(:pio, :integer, null: false, default: 0)
      add(:state, :boolean, null: false, default: false)
      add(:ttl_ms, :integer, null: false, default: 1000)

      timestamps()
    end

    create_if_not_exists(index(:switch, [:device], unique: true))
    create_if_not_exists(index(:switch, [:discovered_at]))
    create_if_not_exists(index(:switch, [:last_seen_at]))

    create_if_not_exists(index(:switch_cmd, [:switch_id]))
    create_if_not_exists(index(:switch_cmd, [:refid], unique: true))

    create_if_not_exists(index(:switch_state, [:switch_id]))
    create_if_not_exists(index(:switch_state, [:name], unique: true))
    create_if_not_exists(index(:switch_state, [:switch_id, :pio], unique: true))

    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    drop_if_exists(table(:sensor_temperature))
    drop_if_exists(index(:sensor_temperature, [:sensor_id]))
    drop_if_exists(table(:sensor_relhum))
    drop_if_exists(index(:sensor_relhum, [:sensor_id]))

    drop_if_exists(table(:sensor))
    drop_if_exists(index(:sensor, [:name], unique: true))
    drop_if_exists(index(:sensor, [:device], unique: true))
    drop_if_exists(index(:sensor, [:reading_at]))
    drop_if_exists(index(:sensor, [:last_seen_at]))

    create_if_not_exists table(:sensor) do
      add(:name, :string, size: 40, null: false)
      add(:description, :text, default: "new sensor")
      add(:device, :string, size: 40, null: false)
      add(:type, :string, size: 10, null: false, default: "undef")
      add(:dev_latency, :bigint, null: true, default: nil)
      add(:reading_at, :utc_datetime, default: before_now)
      add(:last_seen_at, :utc_datetime, default: current_time)

      timestamps()
    end

    create_if_not_exists(index(:sensor, [:name], unique: true))
    create_if_not_exists(index(:sensor, [:device], unique: true))
    create_if_not_exists(index(:sensor, [:reading_at]))
    create_if_not_exists(index(:sensor, [:last_seen_at]))

    create_if_not_exists table(:sensor_temperature) do
      add(
        :sensor_id,
        references(:sensor, on_delete: :delete_all, on_update: :update_all)
      )

      add(:tc, :float, null: true, default: nil)
      add(:tf, :float, null: true, default: nil)
      add(:ttl_ms, :integer, null: false, default: 10_000)

      timestamps()
    end

    create_if_not_exists(index(:sensor_temperature, [:sensor_id]))

    create_if_not_exists table(:sensor_relhum) do
      add(
        :sensor_id,
        references(:sensor, on_delete: :delete_all, on_update: :update_all)
      )

      add(:rh, :float, null: true, default: nil)
      add(:ttl_ms, :integer, null: false, default: 10_000)

      timestamps()
    end

    create_if_not_exists(index(:sensor_relhum, [:sensor_id]))

    drop_if_exists(index(:dutycycle, [:name]))
    drop_if_exists(index(:dutycycle_state, [:dutycycle_id]))
    drop_if_exists(index(:dutycycle_mode, [:dutycycle_id, :name]))
    drop_if_exists(index(:dutycycle_profile, [:dutycycle_id]))

    drop_if_exists(table(:dutycycle_state))
    drop_if_exists(table(:dutycycle_mode))
    drop_if_exists(table(:dutycycle_profile))
    drop_if_exists(table(:dutycycle))

    create table(:dutycycle) do
      add(:name, :string, size: 50, null: false)
      add(:description, :string, size: 100)
      add(:enable, :boolean, default: false)
      add(:device, :string, size: 25, null: false)

      timestamps()
    end

    create table(:dutycycle_state) do
      add(
        :dutycycle_id,
        references(:dutycycle, on_delete: :delete_all, on_update: :update_all)
      )

      add(:state, :string, size: 15, null: false, default: "stopped")
      add(:dev_state, :boolean, default: false, null: false)
      add(:run_at, :utc_datetime, default: nil)
      add(:run_end_at, :utc_datetime, default: nil)
      add(:run_remain_ms, :integer, default: nil)
      add(:idle_at, :utc_datetime, default: nil)
      add(:idle_end_at, :utc_datetime, default: nil)
      add(:idle_remain_ms, :integer, default: nil)
      add(:started_at, :utc_datetime, default: nil)
      add(:state_at, :utc_datetime, null: false, default: current_time)

      timestamps()
    end

    create table(:dutycycle_mode) do
      add(
        :dutycycle_id,
        references(:dutycycle, on_delete: :delete_all, on_update: :update_all)
      )

      add(:name, :string, size: 25, null: false)
      add(:active, :boolean, default: false, null: false)
      add(:run_ms, :integer, default: 600_000, null: false)
      add(:idle_ms, :integer, default: 600_000, null: false)

      timestamps()
    end

    create_if_not_exists(index(:dutycycle, [:name], unique: true))
    create_if_not_exists(index(:dutycycle_state, [:dutycycle_id]))
    create_if_not_exists(index(:dutycycle_mode, [:dutycycle_id, :name], unique: true))

    drop_if_exists(table(:mixtanks))
    drop_if_exists(index(:mixtanks, [:name]))

    create table(:mixtanks) do
      add(:name, :string, size: 25, null: false)
      add(:description, :text)
      add(:enable, :boolean, null: false)
      add(:sensor, :string, size: 25, null: false)
      add(:ref_sensor, :string, size: 25, null: false)
      add(:heat_sw, :string, size: 25, null: false)
      add(:heat_state, :boolean, null: false, default: false)
      add(:air_sw, :string, size: 25, null: false)
      add(:air_state, :boolean, null: false, default: false)
      add(:air_run_ms, :integer, null: false, default: 0)
      add(:air_idle_ms, :integer, null: false, default: 0)
      add(:pump_sw, :string, size: 25, null: false)
      add(:pump_state, :boolean, null: false, default: false)
      add(:pump_run_ms, :integer, null: false, default: 0)
      add(:pump_idle_ms, :integer, null: false, default: 0)
      add(:state_at, :utc_datetime, default: current_time)

      timestamps()
    end

    create(index(:mixtanks, [:name], unique: true))

    drop_if_exists(index(:chambers, [:name]))
    drop_if_exists(table(:chambers))

    create_if_not_exists table(:chambers) do
      add(:name, :string, size: 25, null: false, default: "new chamber")
      add(:description, :text, default: "no description")
      add(:enable, :boolean, null: false, default: false)
      add(:temp_sensor_pri, :string, size: 25, null: false, default: "foobar")
      add(:temp_sensor_sec, :string, size: 25, null: false, default: "foobar")
      add(:temp_setpt, :integer, null: false, default: 85)
      add(:heat_sw, :string, size: 25, null: false, default: "foobar")
      add(:heat_control_ms, :integer, null: false, default: 15_000)
      add(:relh_sensor, :string, size: 25, null: false, default: "foobar")
      add(:relh_setpt, :integer, null: false, default: 90)
      add(:relh_control_ms, :integer, null: false, default: 30_000)
      add(:relh_sw, :string, size: 25, null: false, default: "foobar")
      add(:relh_freq_ms, :integer, null: false, default: 20 * 60 * 1000)
      add(:relh_dur_ms, :integer, null: false, default: 2 * 60 * 1000)
      add(:air_stir_sw, :string, size: 25, null: false, default: "foobar")
      add(:air_stir_temp_diff, :float, null: false, default: 0.0)
      add(:fresh_air_sw, :string, size: 25, null: false, default: "foobar")
      add(:fresh_air_freq_ms, :integer, null: false, default: 900_000)
      add(:fresh_air_dur_ms, :integer, null: false, default: 300_000)
      add(:warm, :boolean, null: false, default: true)
      add(:mist, :boolean, null: false, default: true)
      add(:fae, :boolean, null: false, default: true)
      add(:stir, :boolean, null: false, default: true)

      timestamps()
    end

    create_if_not_exists(index(:chambers, [:name], unique: true))
  end
end
