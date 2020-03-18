defmodule Repo.Migrations.SwitchRedesign do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:switch_alias))
    drop_if_exists(table(:switch_command))
    drop_if_exists(table(:switch_device))

    #
    # %Switch.Device{}
    #

    create_if_not_exists table(:switch_device) do
      add(:device, :string, null: false)
      add(:states, :map, null: false)
      add(:host, :string, null: false)
      add(:dev_latency_us, :integer, null: false, default: 0)
      add(:ttl_ms, :integer, null: false, default: 60_000)
      add(:discovered_at, :utc_datetime_usec, null: false)
      add(:last_cmd_at, :utc_datetime_usec, null: false)
      add(:last_seen_at, :utc_datetime_usec, null: false)
      add(:log_opts, :map, null: false)

      timestamps()
    end

    create_if_not_exists(index("switch_device", [:device], unique: true))

    create_if_not_exists(
      index("switch_device", [:device],
        using: :hash,
        name: "switch_device_device_hash_index"
      )
    )

    #
    # %Switch.Command{}
    #

    create_if_not_exists table(:switch_command) do
      add(
        :dev_id,
        references(:switch_device,
          on_delete: :delete_all,
          on_update: :update_all
        )
      )

      add(:refid, :uuid, null: false)
      add(:acked, :boolean, null: false, default: false)
      add(:orphan, :boolean, null: false, default: false)
      add(:rt_latency_us, :integer, null: false, default: 0)
      add(:sent_at, :utc_datetime_usec, null: false)
      add(:ack_at, :utc_datetime_usec, null: true)
      add(:log_opts, :map, null: false)

      timestamps()
    end

    create_if_not_exists(index(:switch_command, [:refid], unique: true))
    create_if_not_exists(index(:switch_command, [:refid], using: :hash))
    create_if_not_exists(index(:switch_command, [:acked, :orphan]))
    create_if_not_exists(index(:switch_command, [:ack_at, :sent_at]))

    #
    # %Switch.Name{}
    #

    create_if_not_exists table(:switch_alias) do
      add(:name, :string, null: false)
      add(:description, :string, size: 50)
      add(:device, :string, null: false)
      add(:pio, :integer, null: false)
      add(:invert_state, :boolean, null: false, default: true)
      add(:ttl_ms, :integer, default: 60_000)
      add(:log_opts, :map, null: false)

      timestamps()
    end

    create_if_not_exists(index(:switch_alias, [:name], unique: true))

    create_if_not_exists(
      index(:switch_alias, [:device],
        using: :hash,
        name: "switch_alias_device_hash_index"
      )
    )

    create_if_not_exists(
      index("switch_alias", [:name],
        using: :hash,
        name: "switch_alias_name_hash_index"
      )
    )
  end
end
