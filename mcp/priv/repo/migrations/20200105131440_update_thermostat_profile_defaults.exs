defmodule Repo.Migrations.UpdateThermostatProfileDefaults do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:thermostat_profile) do
      modify(:check_ms, :integer, default: 300)
      modify(:low_offset, :float, default: -0.2)
    end
  end
end
