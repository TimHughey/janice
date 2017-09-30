defmodule Mcp.Repo.Migrations.AddChamberFunctionControl do
  @moduledoc :false

  use Ecto.Migration

  def change do
    alter table(:chambers) do
      add :warm, :boolean, null: false, default: true
      add :mist, :boolean, null: false, default: true
      add :fae, :boolean, null: false, default: true
      add :stir, :boolean, null: false, default: true
    end
  end
end
