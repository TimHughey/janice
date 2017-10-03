defmodule Mcp.Repo.Migrations.AddDevAliasTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)

    drop_if_exists table(:dev_alias)
    drop_if_exists index(:dev_alias, [:device])
    drop_if_exists index(:dev_alias, [:friendly_name])
    create_if_not_exists table(:dev_alias) do
      add :device, :string, size: 40, null: false
      add :friendly_name, :string, size: 25, null: false
      add :description, :text
      add :dt_last_seen, :utc_datetime, default: current_time

      timestamps()
    end

    create_if_not_exists index(:dev_alias, [:device], unique: true)
    create_if_not_exists index(:dev_alias, [:friendly_name], unique: true)
    execute("create sequence if not exists seq_dev_alias minvalue 1 start with 1")
  end

#   add :value, :map, null: false, default: %{}

end
