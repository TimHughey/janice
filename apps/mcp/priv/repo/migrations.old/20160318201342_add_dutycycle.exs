defmodule Mcp.Repo.Migrations.AddDutycycle do
  use Ecto.Migration

  def change do

    create table(:dutycycles) do
      add :name,          :string, size: 25, null: false
      add :description,   :string, size: 100
      add :enable,        :boolean, default: false
      add :device_sw,     :string, size: 25, null: false
      add :run_ms,        :integer, default: 600000
      add :idle_ms,       :integer, default: 600000
      add :state_at,      :datetime 

      timestamps
    end

    create index(:dutycycles, [:name])

  end
end
