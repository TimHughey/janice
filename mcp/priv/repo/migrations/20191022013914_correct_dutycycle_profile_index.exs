defmodule Repo.Migrations.CorrectDutycycleProfileIndex do
  @moduledoc false

  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:dutycycle_profile, [:dutycycle_id, :name], unique: true)
    )

    create_if_not_exists(
      index(:dutycycle_profile, [:name, :dutycycle_id], unique: true)
    )
  end
end
