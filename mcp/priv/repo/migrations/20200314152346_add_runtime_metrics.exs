defmodule Repo.Migrations.AddRuntimeMetrics do
  use Ecto.Migration

  def change do
    alter table(:pwm) do
      modify(:runtime_metrics, :map,
        null: false,
        default: default_runtime_metrics()
      )
    end

    alter table(:sensor) do
      add(:runtime_metrics, :map,
        null: false,
        default: default_runtime_metrics()
      )
    end

    alter table(:remote) do
      add(:runtime_metrics, :map,
        null: false,
        default: default_runtime_metrics()
      )
    end

    alter table(:switch) do
      add(:runtime_metrics, :map,
        null: false,
        default: default_runtime_metrics()
      )
    end

    alter table(:switch_state) do
      add(:runtime_metrics, :map,
        null: false,
        default: default_runtime_metrics()
      )
    end
  end

  defp default_runtime_metrics, do: %{external_update: false, cmd_rt: true}
end
