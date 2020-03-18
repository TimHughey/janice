defmodule Switch.Command do
  @moduledoc false

  require Logger
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_command" do
    field(:sw_name, :string)
    field(:refid, Ecto.UUID, autogenerate: true)
    field(:acked, :boolean)
    field(:orphan, :boolean)
    field(:rt_latency_us, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)
    field(:runtime_metrics, :map, default: %{log: false})

    belongs_to(:switch_device, Switch.Device, foreign_key: :dev_id)

    timestamps()
  end

  # defp possible_changes,
  #   do: [
  #     :sw_name,
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
