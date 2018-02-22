defmodule Repo.Migrations.AddRemotePreferredVsn do
  use Ecto.Migration

  def change do
    alter table("remote") do
      add(:preferred_vsn, :string, default: "stable")
    end
  end
end
