defmodule Repo.Migrations.AddRemoteUptime do
  use Ecto.Migration

  def change do
    alter table("remote") do
      add(:uptime_us, :bigint, default: 0)
    end
  end
end
