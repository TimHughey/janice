defmodule Repo.Migrations.AddPulseWidth do
  @moduledoc false

  use Ecto.Migration

  def change do
    drop_if_exists(table(:pwm_cmd))
    drop_if_exists(table(:pwm))

    create_if_not_exists table(:pwm) do
      add(:name, :string, null: false)
      add(:description, :string, null: false, default: "")
      add(:device, :string, null: false)
      add(:host, :string, null: false)
      add(:duty, :integer, null: false, default: 0)
      add(:duty_max, :integer, null: false, default: 4095)
      add(:duty_min, :integer, null: false, default: 0)
      add(:dev_latency_us, :integer, default: 0)
      add(:log, :boolean, null: false, default: false)
      add(:ttl_ms, :integer, default: 60_000)
      add(:reading_at, :utc_datetime_usec)
      add(:last_seen_at, :utc_datetime_usec)
      add(:metric_at, :utc_datetime_usec)
      add(:metric_freq_secs, :integer, default: 60)
      add(:discovered_at, :utc_datetime_usec)
      add(:last_cmd_at, :utc_datetime_usec)

      timestamps()
    end

    create_if_not_exists(index("pwm", [:name], unique: true))
    create_if_not_exists(index("pwm", [:device], unique: true))
    create_if_not_exists(index("pwm", [:host]))
    create_if_not_exists(index("pwm", [:last_cmd_at]))
    create_if_not_exists(index("pwm", [:last_seen_at]))
  end
end
