defmodule Repo.Migrations.AddThermostat do
  @moduledoc """

  """
  use Ecto.Migration

  def change do
    create_if_not_exists table(:thermostat) do
      add(:name, :string, size: 50, null: false)
      add(:description, :string, size: 100)
      add(:owned_by, :string, size: 50, null: true)
      add(:enable, :boolean, null: false, default: false)
      add(:switch, :string, size: 50, null: false)
      add(:active_profile, :string, size: 25, null: true)
      add(:sensor, :string, size: 40, null: false)
      add(:state, :string, size: 15, null: false, default: "new")
      add(:state_at, :utc_datetime, null: true)
      add(:log_activity, :boolean, null: false, default: false)

      timestamps()
    end

    create_if_not_exists(index(:thermostat, [:name], unique: true))

    create_if_not_exists table(:thermostat_profile) do
      add(:thermostat_id, references(:thermostat, on_delete: :delete_all, on_update: :update_all))
      add(:name, :string, size: 25, null: false)
      add(:low_offset, :float, null: false, default: 0.0)
      add(:high_offset, :float, null: false, default: 0.0)
      add(:check_ms, :integer, null: false, default: 60_000)

      add(:ref_sensor, :string, size: 40, null: true)
      add(:ref_offset, :float, null: true)

      # constant set point when ref_sensor is null
      add(:fixed_setpt, :float, null: true)

      timestamps()
    end

    create_if_not_exists(index(:thermostat_profile, [:id, :name], unique: true))
  end
end
