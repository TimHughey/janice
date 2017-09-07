defmodule Mcp.Repo.Migrations.ChamberAirStirDiffToFloat do
  @moduledoc false

  use Ecto.Migration

  def change do
    alter table(:chambers) do
      modify :air_stir_temp_diff, :float, default: 0.0, null: false
      end
  end
end
