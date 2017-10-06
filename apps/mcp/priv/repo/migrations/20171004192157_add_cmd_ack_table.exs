defmodule Mcp.Repo.Migrations.AddCmdAckTable do
  @moduledoc """
  """
  use Ecto.Migration

  def change do
    current_time = fragment(~s/(now() at time zone 'utc')/)

    sw_cmd_index_col = [:switch_id, :refid, :dt_ack, :dt_sent]
    sw_cmd_index = index(:switch_cmd, sw_cmd_index_col, unique: true)

    drop_if_exists table(:switch_cmd)
    drop_if_exists sw_cmd_index

    create_if_not_exists table(:switch_cmd) do
      add :refid, :string, size: 40, null: false
      add :switch_id, references(:switch)
      add :acked, :boolean, null: false, default: false
      add :dev_latency, :float, null: true, default: nil
      add :rt_latency, :float, null: true, default: nil
      add :dt_sent, :utc_datetime, null: false, default: current_time
      add :dt_ack, :utc_datetime, null: true, default: nil

      timestamps()
    end

    create_if_not_exists sw_cmd_index
  end
end
