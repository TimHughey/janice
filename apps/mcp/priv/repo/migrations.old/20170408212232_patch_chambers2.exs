defmodule Mcp.Repo.Migrations.PatchChambers2 do
  use Ecto.Migration

  def change do
    alter table(:chambers) do
      add :relh_sw, :string, size: 25, null: false, default: "foobar" 
    end
  end
end
