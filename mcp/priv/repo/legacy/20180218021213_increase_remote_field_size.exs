defmodule Repo.Migrations.IncreaseRemoteFieldSize do
  use Ecto.Migration

  def change do
    alter table("remote") do
      modify(:host, :string, size: 20, null: false)
      modify(:name, :string, size: 35, null: false)
    end
  end
end
