defmodule Repo.Migrations.DutycycleImproveHandlingOfStop2 do
  use Ecto.Migration

  def change do
    alter table(:dutycycle) do
      modify(:last_profile, :text, default: "none")

      add_if_not_exists(:stopped, :boolean, default: true)
    end
  end
end
