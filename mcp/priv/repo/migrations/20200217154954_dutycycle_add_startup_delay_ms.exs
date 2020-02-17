defmodule Repo.Migrations.DutycycleAddStartupDelayMS do
  use Ecto.Migration

  def change do
    alter table("dutycycle") do
      add(:startup_delay_ms, :integer, default: 10_000)
    end
  end
end
