defmodule Mcp.Repo.Migrations.RefactorSwitchStates do
  @moduledoc """
  """
  use Ecto.Migration

  def change do

    current_time = fragment(~s/(now() at time zone 'utc')/)
    # before_now = fragment(~s/now() at time zone 'utc' - interval '3 month')/)
    before_now = fragment(~s/(now() at time zone 'utc' - interval '3 hour')/)

    sw_cmd_index_col = [:switch_id, :refid, :dt_ack, :dt_sent]
    sw_cmd_index = index(:switch_cmd, sw_cmd_index_col, unique: true)

    drop_if_exists table(:switch_cmd)
    drop_if_exists sw_cmd_index

    drop_if_exists table(:switch)
    drop_if_exists index(:switch, [:device])

    create_if_not_exists table(:switch) do
      add :device, :string, size: 40, null: false
      add :enabled, :boolean, null: false, default: true
      add :dev_latency, :float, null: true, default: nil
      add :dt_last_cmd, :utc_datetime, default: before_now
      add :dt_discovered, :utc_datetime, default: current_time
      add :dt_last_seen, :utc_datetime, default: current_time

      timestamps()
    end

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

    create_if_not_exists index(:switch, [:device], unique: true)
    create_if_not_exists index(:switch, [:dt_discovered])
    create_if_not_exists index(:switch, [:dt_last_seen])

    create_if_not_exists sw_cmd_index

    ##
    ## SensorTemperature
    ##

    drop_if_exists table(:switch_state)
    drop_if_exists index(:switch_state, [:switch_id])

    create_if_not_exists table(:switch_state) do
      add :switch_id, references(:switch)
      add :pio, :integer, null: false, default: 0
      add :state, :boolean, null: true, default: nil
      add :ttl_ms, :integer, null: false, default: 1000

      timestamps()
    end

    create_if_not_exists index(:switch_state, [:switch_id])
  end
end
