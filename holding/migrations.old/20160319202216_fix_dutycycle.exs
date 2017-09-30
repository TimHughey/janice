defmodule Mcp.Repo.Migrations.FixDutycycle do
  use Ecto.Migration

  def change do

    drop_if_exists table(:dutycycles)
    drop_if_exists index(:dutycycles, [:name])

    create table(:dutycycles) do
      add :name,          :string, size: 25, null: false
      add :description,   :string, size: 100
      add :enable,        :boolean, default: false
      add :device_sw,     :string, size: 25, null: false
      add :device_state,  :boolean, default: false, null: false
      add :run_ms,        :integer, default: 600000
      add :idle_ms,       :integer, default: 600000
      add :state_at,      :datetime

      timestamps
    end

    create index(:dutycycles, [:name])

  end
end
