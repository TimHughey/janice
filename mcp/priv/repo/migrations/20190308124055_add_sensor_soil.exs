defmodule Repo.Migrations.AddSensorSoil do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:sensor_soil) do
      add(
        :sensor_id,
        references(:sensor, on_delete: :delete_all, on_update: :update_all)
      )

      add(:moisture, :float, null: true, default: nil)
      add(:ttl_ms, :integer, null: false, default: 10_000)

      timestamps()
    end

    create_if_not_exists(index(:sensor_soil, [:sensor_id]))
  end
end
