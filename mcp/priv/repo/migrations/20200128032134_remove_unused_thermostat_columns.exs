defmodule Repo.Migrations.RemoveUnusedThermostatColumns do
  use Ecto.Migration

  def change do
    alter table(:thermostat) do
      remove_if_exists(:owned_by, :string)
      remove_if_exists(:enable, :boolean)
    end

    rename(table(:thermostat), :log_activity, to: :log)
  end
end
