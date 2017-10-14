defmodule Mcp.Repo.Migrations.AddChamberMixtankDutycycles do
use Ecto.Migration

def change do
  current_time = fragment(~s/(now() at time zone 'utc')/)

  drop_if_exists table(:dutycycles)
  drop_if_exists index(:dutycycles, [:name])

  create table(:dutycycles) do
    add :name,          :string, size: 25, null: false
    add :description,   :string, size: 100
    add :enable,        :boolean, default: false
    add :device_sw,     :string, size: 25, null: false
    add :device_state,  :boolean, default: false, null: false
    add :run_ms,        :integer, default: 600_000
    add :idle_ms,       :integer, default: 600_000
    add :state_at,      :utc_datetime

    timestamps()
  end
  create index(:dutycycles, [:name])

  drop_if_exists table(:mixtanks)
  drop_if_exists index(:mixtanks, [:name])
  create table(:mixtanks) do
    add :name, :string, size: 25, null: false
    add :description, :text
    add :enable, :boolean, null: false
    add :sensor, :string, size: 25, null: false
    add :ref_sensor, :string, size: 25, null: false
    add :heat_sw, :string, size: 25, null: false
    add :heat_state, :boolean, null: false, default: false
    add :air_sw, :string, size: 25, null: false
    add :air_state, :boolean, null: false, default: false
    add :air_run_ms, :integer, null: false, default: 0
    add :air_idle_ms, :integer, null: false, default: 0
    add :pump_sw, :string, size: 25, null: false
    add :pump_state, :boolean, null: false, default: false
    add :pump_run_ms, :integer, null: false, default: 0
    add :pump_idle_ms, :integer, null: false, default: 0
    add :state_at, :utc_datetime, default: current_time

    timestamps()
  end
  create index(:mixtanks, [:name], unique: true)

  drop_if_exists index(:chambers, [:name])
  drop_if_exists table(:chambers)

  create_if_not_exists table(:chambers) do
    add :name, :string, size: 25, null: false, default: "new chamber"
    add :description, :text, default: "no description"
    add :enable, :boolean, null: false, default: false
    add :temp_sensor_pri, :string, size: 25, null: false, default: "foobar"
    add :temp_sensor_sec, :string, size: 25, null: false, default: "foobar"
    add :temp_setpt, :integer, null: false, default: 85
    add :heat_sw, :string, size: 25, null: false, default: "foobar"
    add :heat_control_ms, :integer, null: false, default: 15_000
    add :relh_sensor, :string, size: 25, null: false, default: "foobar"
    add :relh_setpt, :integer, null: false, default: 90
    add :relh_control_ms, :integer, null: false, default: 30_000
    add :relh_sw, :string, size: 25, null: false, default: "foobar"
    add :relh_freq_ms, :integer, null: false, default: 20*60*1000
    add :relh_dur_ms, :integer, null: false, default: 2*60*1000
    add :air_stir_sw, :string, size: 25, null: false, default: "foobar"
    add :air_stir_temp_diff, :float, null: false, default: 0.0
    add :fresh_air_sw, :string, size: 25, null: false, default: "foobar"
    add :fresh_air_freq_ms, :integer, null: false, default: 900_000
    add :fresh_air_dur_ms, :integer, null: false, default: 300_000
    add :warm, :boolean, null: false, default: true
    add :mist, :boolean, null: false, default: true
    add :fae, :boolean, null: false, default: true
    add :stir, :boolean, null: false, default: true

    timestamps()
  end

  create_if_not_exists index(:chambers, [:name], unique: true)

end
end
