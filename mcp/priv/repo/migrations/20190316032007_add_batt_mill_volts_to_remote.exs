defmodule Repo.Migrations.AddBattMillVoltsToRemote do
  use Ecto.Migration

  def change do
    alter table("remote") do
      add(:batt_mv, :integer, default: 0)
      add(:reset_reason, :string, size: 25, default: "unknown")
    end
  end
end
