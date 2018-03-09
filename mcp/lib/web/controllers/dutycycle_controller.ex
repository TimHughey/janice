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
    dutycycles = Dutycycle.Server.all(:as_maps)

    data =
      for m <- dutycycles do
        m = Map.put_new(m, :type, "dutycycle")

        state =
          m.state
          |> Map.put_new(:started_at_secs, to_seconds(m.state.started_at))
          |> Map.put_new(:run_at_secs, to_seconds(m.state.run_at))
          |> Map.put_new(:run_at_end_secs, to_seconds(m.state.run_end_at))
          |> Map.put_new(:idle_at_secs, to_seconds(m.state.idle_at))
          |> Map.put_new(:idle_at_end_secs, to_seconds(m.state.idle_end_at))
          |> Map.put_new(:state_at_secs, to_seconds(m.state.state_at))

        active_profile = Dutycycle.Server.profiles(m.name, only_active: true)

        Map.put(m, :state, state) |> Map.put(:activeProfile, active_profile)
      end

    resp = %{data: data, items: Enum.count(data), mtime: Timex.local() |> Timex.to_unix()}

    json(conn, resp)
  end

  # def delete(conn, %{"id" => id}) do
  #   Logger.debug(fn -> ~s(DELETE #{conn.request_path}) end)
  #
  #   {rows, _} = Remote.delete(String.to_integer(id))
  #
  #   json(conn, %{rows: rows})
  # end
  #
  # def update(%{method: "PATCH"} = conn, %{"id" => id_str} = _params) do
  #   Logger.debug(fn -> ~s(#{conn.method} #{conn.request_path}) end)
  #   id = String.to_integer(id_str)
  #   dc = Dutycycle.get_by(id: id)
  #
  #   resp = %{id: dc.id, name: dc.name}
  #
  #   json(conn, resp)
  # end

  defp to_seconds(dt) do
    secs = if is_nil(dt), do: nil, else: Timex.diff(Timex.now(), dt, :seconds)

    if secs < 0, do: secs * -1, else: secs
  end
end
