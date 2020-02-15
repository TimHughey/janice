defmodule Repo.Migrations.AddDutycycleScheduledWorkandDeviceCheck do
  use Ecto.Migration

  def change do
    alter table("dutycycle") do
      add(:scheduled_work_ms, :integer, default: 750)
    end

    alter table("dutycycle_profile") do
      add(:device_check_ms, :integer, default: 60_000)
    end
  end
end
