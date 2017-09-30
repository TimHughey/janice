defmodule Mcp.Repo.Migrations.PatchChambers do
  use Ecto.Migration

  def change do
    alter table(:chambers) do
      add :relh_control_ms, :integer, null: false, default: 30_000
    end
  end
end
