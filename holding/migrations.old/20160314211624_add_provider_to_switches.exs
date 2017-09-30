defmodule Mcp.Repo.Migrations.AddProviderToSwitches do
  use Ecto.Migration

  def change do
    alter table(:switches) do
      add :provider, :string, default: "owfs", size: 10
    end

    execute "UPDATE switches SET provider = 'owfs'"

    alter table(:switches) do
      modify :provider, :string, default: "owfs", size: 10, null: false
    end

  end
end
