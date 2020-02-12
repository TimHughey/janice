defmodule Repo.Migrations.ChangeSwitchStateDefaultTTL do
  use Ecto.Migration

  def change do
    alter table(:switch_state) do
      modify(:ttl_ms, :integer, default: 60_000)
    end
  end
end
