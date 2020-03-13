defmodule Fact.Remote do
  @moduledoc false

  require Logger
  use Timex

  import Fact.Influx, only: [write: 2]

  @env Application.get_env(:mcp, :build_env, "unknown")

  #   %{
  #   points: [
  #     %{
  #       database: "my_database", # Can be omitted, so default is used.
  #       measurement: "my_measurement",
  #       fields: %{answer: 42, value: 1},
  #       tags: %{foo: "bar"},
  #       timestamp: 1439587926000000000 # Nanosecond unix timestamp with
  #                                        default precision, can be omitted.
  #     },
  #     # more points possible ...
  #   ],
  #   database: "my_database", # Can be omitted, so default is used.
  # }
  # |> MyApp.MyConnection.write()

  def record(%{metadata: :ok} = r) do
    point(r) |> write(precision: :nanosecond, async: true)
  end

  def record(_catchall), do: false

  defp point(%{msg_recv_dt: msg_recv_dt} = r) do
    fields =
      Map.take(r, [
        :uptime_us,
        :heap_free,
        :heap_min,
        :batt_mv,
        :reset_reason,
        :ap_rssi
      ])

    tags = Map.take(r, [:name, :host]) |> Map.put(:env, @env)

    %{
      points: [
        %{
          measurement: "remote",
          fields: fields,
          tags: tags,
          timestamp: DateTime.to_unix(msg_recv_dt, :nanosecond)
        }
      ]
    }
  end
end
