defmodule Mcp.Repo.Migrations.AddSensorsTable do
  use Ecto.Migration

  def change do
    drop_if_exists table(:sensors)
    drop_if_exists index(:sensors, [:name])
    create_if_not_exists table(:sensors) do
      add :name, :string, size:32, null: false
      add :description, :text
      add :value, :map, null: false, default: %{}
      add :read_at, :datetime, default: fragment(~s/(now() at time zone 'utc')/)

      timestamps
    end
    create_if_not_exists index(:sensors, [:name], unique: true)
    execute("create sequence"
              "if not exists"
              "dev_alias_seq"
              " minvalue 1 start with 1")
  end
end
