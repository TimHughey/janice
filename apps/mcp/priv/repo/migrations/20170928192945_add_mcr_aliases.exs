defmodule Mcp.Repo.Migrations.AddMcrAliasTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)

    drop_if_exists table(:mcr_aliases)
    drop_if_exists index(:mcr_aliases, [:device])
    drop_if_exists index(:mcr_aliases, [:friendly_name])
    create_if_not_exists table(:mcr_aliases) do
      add :device, :string, size: 40, null: false
      add :friendly_name, :string, size: 20, null: false
      add :description, :text
      add :dt_last_used, :utc_datetime, default: current_time

      timestamps()
    end

    create_if_not_exists index(:mcr_aliases, [:device], unique: true)
    create_if_not_exists index(:mcr_aliases, [:friendly_name], unique: true)
    execute("create sequence if not exists mcr_alias_seq minvalue 1 start with 1")
  end

#   add :value, :map, null: false, default: %{}

end
