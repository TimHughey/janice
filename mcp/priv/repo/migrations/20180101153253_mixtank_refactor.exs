defmodule Repo.Migrations.MixtankRefactor do
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)

    drop_if_exists table(:mixtanks)  # note: legacy table is plural
    drop_if_exists index(:mixtanks, [:name])

    create table(:mixtank) do
      add :name, :string, size: 50, null: false
      add :comment, :text, null: true, default: nil
      add :enable, :boolean, null: false, default: false
      add :sensor, :string, size: 25, null: false
      add :ref_sensor, :string, size: 25, null: false
      add :pump, :string, size: 50, null: false
      add :air, :string, size: 50, null: false
      add :heater, :string, size: 50, null: false
      add :fill, :string, size: 50, null: false
      add :replenish, :string, size: 50, null: false

      timestamps()
    end

    create table(:mixtank_profile) do
      add :mixtank_id,
        references(:mixtank, on_delete: :delete_all, on_update: :update_all)
      add :name, :string, size: 25, null: false
      add :active, :boolean, default: false, null: false
      add :pump, :string, size: 25, null: false
      add :air, :string, size: 25, null: false
      add :fill, :string, size: 25, null: false
      add :replenish, :string, size: 25, null: false
      add :temp_diff, :integer, default: 0, null: false

      timestamps()
    end

    create table(:mixtank_state) do
      add :mixtank_id,
        references(:mixtank, on_delete: :delete_all, on_update: :update_all)
      add :state, :string, size: 15, null: false, default: "stopped"
      add :started_at, :utc_datetime, default: nil
      add :state_at, :utc_datetime, null: false, default: current_time

      timestamps()
    end

    create_if_not_exists index(:mixtank, [:name], unique: true)
    create_if_not_exists index(:mixtank_state, [:mixtank_id])
    create_if_not_exists index(:mixtank_profile, [:mixtank_id, :name],
                                unique: true)

  end
end
