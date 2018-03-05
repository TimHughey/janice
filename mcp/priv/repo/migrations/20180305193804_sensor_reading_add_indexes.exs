defmodule Repo.Migrations.SensorReadingAddIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:sensor_temperature, [:inserted_at]))
    create_if_not_exists(index(:sensor_relhum, [:inserted_at]))
  end
end
