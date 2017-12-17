defmodule Mcp.Repo.Migrations.RefactorDutycycle do
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)

    drop_if_exists table(:dutycycles)
    drop_if_exists index(:dutycycles, [:name])

    create table(:dutycycle) do
      add :name,          :string, size: 50, null: false
      add :description,   :string, size: 100
      add :enable,        :boolean, default: false
      add :device,        :string, size: 25, null: false

      timestamps()
    end

    create table(:dutycycle_state) do
      add :dutycycle_id,
        references(:dutycycle, on_delete: :delete_all, on_update: :update_all)
      add :state, :string, size: 15, null: false, default: "stopped"
      add :dev_state, :boolean, default: false, null: false
      add :run_at, :utc_datetime, default: nil
      add :run_end_at, :utc_datetime, default: nil
      add :run_remain_ms, :integer, default: nil
      add :idle_at, :utc_datetime, default: nil
      add :idle_end_at, :utc_datetime, default: nil
      add :idle_remain_ms, :integer, default: nil
      add :started_at, :utc_datetime, default: nil
      add :state_at, :utc_datetime, null: false, default: current_time

      timestamps()
    end

    create table(:dutycycle_mode) do
      add :dutycycle_id,
        references(:dutycycle, on_delete: :delete_all, on_update: :update_all)
      add :name, :string, size: 25, null: false
      add :active, :boolean, default: false, null: false
      add :run_ms, :integer, default: 600_000, null: false
      add :idle_ms, :integer, default: 600_000, null: false

      timestamps()
    end

    create_if_not_exists index(:dutycycle, [:name], unique: true)
    create_if_not_exists index(:dutycycle_state, [:dutycycle_id])
    create_if_not_exists index(:dutycycle_mode, [:dutycycle_id, :name], unique: true)
  end
end
