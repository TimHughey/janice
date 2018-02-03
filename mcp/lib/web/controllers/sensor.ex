defmodule Web.SensorController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def index(conn, _params) do
    sensors = Sensor.all(:everything)

    data =
      for s <- sensors do
        %{
          type: "sensor",
          id: s.id,
          name: s.name,
          device: s.device,
          description: s.description,
          dev_latency: s.dev_latency,
          last_seen_secs: humanize_secs(s.last_seen_at),
          reading_secs: humanize_secs(s.reading_at),
          celsius: s.temperature.tc
        }
      end

    resp = %{data: data, items: Enum.count(data), mtime: Timex.local() |> Timex.to_unix()}

    json(conn, resp)
  end

  def delete(conn, %{"id" => id}) do
    Logger.info(fn -> ~s(DELETE #{conn.request_path}) end)

    {rows, _} = Sensor.delete(String.to_integer(id))

    json(conn, %{rows: rows})
  end

  def update(%{method: "PATCH"} = conn, %{"id" => id, "name" => new_name} = _params) do
    Logger.info(fn -> ~s(#{conn.method} #{conn.request_path}) end)

    Sensor.change_name(String.to_integer(id), new_name, "changed via web")

    json(conn, %{name: new_name})
  end

  defp humanize_secs(nil), do: 0

  defp humanize_secs(%DateTime{} = dt) do
    # |> humanize_secs
    Timex.diff(Timex.now(), dt, :seconds)
  end
end
