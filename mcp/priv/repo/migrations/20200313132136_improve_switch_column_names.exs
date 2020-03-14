defmodule Repo.Migrations.ImproveSwitchColumnNames do
  use Ecto.Migration

  def change do
    rename(table(:switch), :dev_latency, to: :dev_latency_us)
  end
end
