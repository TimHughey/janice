defmodule Switch.Command do
  @moduledoc false

  require Logger
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_command" do
    field(:sw_alias, :string)
    field(:refid, Ecto.UUID, autogenerate: true)
    field(:acked, :boolean)
    field(:orphan, :boolean)
    field(:rt_latency_us, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
    end

    belongs_to(:device, Switch.Device,
      source: :device_id,
      references: :id,
      foreign_key: :device_id
    )

    timestamps()
  end

  # defp possible_changes,
  #   do: [
  #     :sw_alias,
  #     :refid,
  #     :acked,
  #     :orphan,
  #     :rt_latency_us,
  #     :sent_at,
  #     :ack_at,
  #     :runtime_metrics,
  #     :switch_device
  #   ]
end
