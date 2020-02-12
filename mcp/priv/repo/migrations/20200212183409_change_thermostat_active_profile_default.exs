defmodule Repo.Migrations.ChangeThermostatActiveProfileDefault do
  use Ecto.Migration

  def change do
    alter table(:thermostat) do
      modify(:active_profile, :string, default: "standby")
    end
  end
end
