defmodule Repo.Migrations.AddThermostatProfileSwitchCheck do
  @moduledoc false

  use Ecto.Migration

  def change do
    alter table("thermostat") do
      add(:switch_check_ms, :integer, default: 15 * 60 * 1000)
    end
  end
end
