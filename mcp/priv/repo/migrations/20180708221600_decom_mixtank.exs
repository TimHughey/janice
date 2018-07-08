defmodule Repo.Migrations.DecomMixtank do
  @moduledoc false
  use Ecto.Migration

  def change do
    drop_if_exists(index(:mixtank, [:name]))
    drop_if_exists(index(:mixtank_state, [:mixtank_id]))
    drop_if_exists(index(:mixtank_prpfile, [:mixtank_id, :name]))

    drop_if_exists(table(:mixtank_state))
    drop_if_exists(table(:mixtank_profile))
    drop_if_exists(table(:mixtank))
  end
end
