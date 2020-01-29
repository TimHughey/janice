defmodule Repo.Migrations.RemoveUnusedDutycycleColumns do
  use Ecto.Migration

  def change do
    alter table(:dutycycle) do
      remove_if_exists(:last_profile, :string)
    end
  end
end
