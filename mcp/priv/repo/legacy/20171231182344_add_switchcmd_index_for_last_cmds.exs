defmodule Repo.Migrations.AddSwitchcmdIndexForLastCmds do
  @moduledoc """
  """
  use Ecto.Migration

  def change do

    create_if_not_exists index(:switch_cmd, [:ack_at])

  end
end
