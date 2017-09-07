defmodule Mcp.Repo.Migrations.AddChambersTable do
  @moduledoc """
  """
  use Ecto.Migration

  def change do
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
      add :air_stir_sw, :string, size: 25, null: false, default: "foobar"
      add :air_stir_temp_diff, :integer, null: false, default: 5
      add :fresh_air_sw, :string, size: 25, null: false, default: "foobar"
      add :fresh_air_freq_ms, :integer, null: false, default: 900_000
      add :fresh_air_dur_ms, :integer, null: false, default: 300_000

      timestamps()
    end

    create_if_not_exists index(:chambers, [:name], unique: true)
  end
end
