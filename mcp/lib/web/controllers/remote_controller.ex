defmodule Web.RemoteController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def index(conn, %{"ota_all" => "true"} = params) do
    log = Map.get(params, :log, true)

    ota_all_res = Remote.ota_update(:all, delay_ms: 10_000, log: log)

    resp = %{
      data: [],
      items: 0,
      mtime: Timex.local() |> Timex.to_unix(),
      ota_all_res: ota_all_res
    }

    json(conn, resp)
  end

  def index(conn, _params) do
    remotes = Remote.all()

    data =
      for r <- remotes do
        %{
          type: "remote",
          id: r.id,
          name: r.name,
          host: r.host,
          hw: r.hw,
          firmware_vsn: r.firmware_vsn,
          preferred_vsn: r.preferred_vsn,
          last_start_secs: to_seconds(r.last_start_at),
          last_seen_secs: to_seconds(r.last_seen_at),
          at_preferred_vsn: Remote.at_preferred_vsn?(r)
        }
      end

    resp = %{data: data, items: Enum.count(data), mtime: Timex.local() |> Timex.to_unix()}

    json(conn, resp)
  end

  def delete(conn, %{"id" => id}) do
    Logger.debug(fn -> ~s(DELETE #{conn.request_path}) end)

    {rows, _} = Remote.delete(String.to_integer(id))

    json(conn, %{rows: rows})
  end

  def update(%{method: "PATCH"} = conn, %{"id" => id_str} = params) do
    Logger.debug(fn -> ~s(#{conn.method} #{conn.request_path}) end)
    id = String.to_integer(id_str)

    # special case for testing
    log = Map.get(params, :log, true)

    new_name = Map.get(params, "name", nil)
    name_res = if new_name, do: Remote.change_name(id, new_name)

    new_preference = Map.get(params, "preferred_vsn", nil)
    prefer_res = if new_preference, do: Remote.change_vsn_preference(id, new_preference)

    ota = Map.get(params, "ota", false)
    ota_res = if ota, do: Remote.ota_update(id, delay_ms: 10_000, log: log)

    restart = Map.get(params, "restart", false)
    restart_res = if restart, do: Remote.restart(id, delay_ms: 3_000)

    resp = %{
      name: name_res,
      preferred_vsn: prefer_res,
      ota: ota_res,
      restart: restart_res
    }

    json(conn, resp)
  end

  defp to_seconds(dt) do
    if is_nil(dt), do: 0, else: Timex.diff(Timex.now(), dt, :seconds)
  end
end
