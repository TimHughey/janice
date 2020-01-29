defmodule Repo.Migrations.DutycycleImproveHandlingOfStop do
  use Ecto.Migration

  def change do
    alter table(:dutycycle) do
      remove_if_exists(:enable, :boolean)
      remove_if_exists(:standalone, :boolean)

      add_if_not_exists(:stopped, :boolean, default: true)
      add_if_not_exists(:last_profile, :string, default: "none")
    end
  end
end
