defmodule Repo.Migrations.AddSwitchCmdOrphanField do
  use Ecto.Migration

  def change do
    alter table("switch_cmd") do
      add :orphan, :boolean, default: false
    end
  end
end
