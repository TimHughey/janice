defmodule Repo.Migrations.AddSensorLastMetricTimestamp do
  use Ecto.Migration

  def change do
    alter table(:remote) do
      add(:metric_freq_secs, :integer, default: 60)
      add(:metric_at, :utc_datetime, default: nil)
    end

    alter table(:sensor) do
      add(:metric_freq_secs, :integer, default: 60)
      add(:metric_at, :utc_datetime, default: nil)
    end
  end
end
