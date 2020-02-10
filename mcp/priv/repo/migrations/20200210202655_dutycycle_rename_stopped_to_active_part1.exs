defmodule Repo.Migrations.DutycycleRenameStoppedToActivePart1 do
  use Ecto.Migration

  def change do
    rename(table(:dutycycle), :stopped, to: :active)
  end
end
