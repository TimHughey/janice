defmodule Mcp.Repo.Migrations.AddSwitchCmdsIndex do
  @moduledoc """
  """
  use Ecto.Migration

  def up do

    # drop the previous index
    sw_cmd_index_col = [:switch_id, :refid, :dt_ack, :dt_sent]
    sw_cmd_index = index(:switch_cmd, sw_cmd_index_col, unique: true)
    drop_if_exists sw_cmd_index

    create_if_not_exists index(:switch_cmd, [:refid], unique: true)
    create_if_not_exists index(:switch_cmd, [:switch_id])
    create_if_not_exists index(:switch_cmd, [:dt_ack])
    create_if_not_exists index(:switch_cmd, [:dt_sent])
  end

  def down do
    drop_if_exists index(:switch_cmd, [:refid], unique: true)
    drop_if_exists index(:switch_cmd, [:switch_id], unique: true)
    drop_if_exists index(:switch_cmd, [:dt_ack])
    drop_if_exists index(:switch_cmd, [:dt_sent])
  end

end
