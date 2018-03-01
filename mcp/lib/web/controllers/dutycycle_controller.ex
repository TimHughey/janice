defmodule Web.DutycycleController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  # def index(conn, %{"ota_all" => "true"} = _params) do
  #   ota_all_res = Remote.ota_update(:all)
  #
  #   resp = %{
  #     data: [],
  #     items: 0,
  #     mtime: Timex.local() |> Timex.to_unix(),
  #     ota_all_res: ota_all_res
  #   }
  #
  #   json(conn, resp)
  # end

  def index(conn, _params) do
    dutycycles = Dutycycle.all()

    data =
      for dc <- dutycycles do
        m = Dutycycle.as_map(dc) |> Map.put_new(:type, "dutycycle")

        state =
          Map.put_new(m.state, :started_at_secs, to_seconds(m.state.started_at))
          |> Map.put_new(:run_at_secs, to_seconds(m.state.run_at))
          |> Map.put_new(:run_at_end_secs, to_seconds(m.state.run_end_at))
          |> Map.put_new(:idle_at_secs, to_seconds(m.state.idle_at))
          |> Map.put_new(:idle_at_end_secs, to_seconds(m.state.idle_end_at))
          |> Map.put_new(:state_at_secs, to_seconds(m.state.state_at))

        Map.put(m, :state, state)
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
    dc = Dutycycle.get_by(id: id)

    resp = %{id: dc.id, name: dc.name}

    json(conn, resp)
  end

  defp to_seconds(dt) do
    secs = if is_nil(dt), do: nil, else: Timex.diff(Timex.now(), dt, :seconds)

    if secs < 0, do: secs * -1, else: secs
  end
end
