defmodule Repo.Migrations.AddDutycycleStandaloneField do
  use Ecto.Migration

  def change do
    alter table("dutycycle") do
      add(:standalone, :boolean, default: false)
    end
  end
end
