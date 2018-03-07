defmodule Repo.Migrations.AddSwitchCmdSentAtIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:switch_cmd, [:sent_at]))
  end
end
