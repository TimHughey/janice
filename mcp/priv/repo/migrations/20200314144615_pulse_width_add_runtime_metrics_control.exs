defmodule Repo.Migrations.PulseWidthAddRuntimeMetricsControl do
  use Ecto.Migration

  def change do
    alter table(:pwm) do
      add(:runtime_metrics, :map, null: false, default: %{external_update: true})
    end
  end
end
