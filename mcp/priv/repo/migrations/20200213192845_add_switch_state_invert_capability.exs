defmodule Repo.Migrations.AddSwitchStateInvertCapability do
  use Ecto.Migration

  def change do
    alter table("switch_state") do
      add(:log, :boolean, default: false)
      add(:invert_state, :boolean, default: false)
    end

    alter table("switch") do
      add(:log, :boolean, default: false)
      remove_if_exists(:enabled, :boolean)
    end
  end
end
