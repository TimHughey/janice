defmodule Repo.Migrations.ImproveSensorColumnNames do
  use Ecto.Migration

  def change do
    rename(table(:sensor), :dev_latency, to: :dev_latency_us)
  end
end
