defmodule Mcp.Repo.Migrations.AddSwitchesTable do
@moduledoc """
"""
use Ecto.Migration

def change do
  current_time = fragment(~s/(now() at time zone 'utc')/)
  # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
  before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

  drop_if_exists table(:switch)
  drop_if_exists index(:switch, [:friendly_name])
  create_if_not_exists table(:switch) do
    add :device, :string, size: 40, null: false
    add :enabled, :boolean, null: false, default: true
    add :states, {:array, :map}, null: false, default: []
    add :last_cmd_at, :utc_datetime, default: before_now
    add :discovered_at, :utc_datetime, default: current_time

    timestamps()
    end

  create_if_not_exists index(:switch, [:device], unique: true)
  end
end
