defmodule WebRemoteControllerTest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  use Web.ConnCase
  use Timex

  alias Web.RemoteController, as: RC

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.webremote" <> Integer.to_string(num) <> "0"
  def name(num), do: "webremote" <> Integer.to_string(num)

  def ext(num),
    do: %{
      host: host(num),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  setup_all do
    :ok
  end

  test "update name" do
    ext(0) |> Remote.external_update()
    id = Remote.all() |> hd() |> Map.get(:id, 0)

    conn = build_conn() |> Map.merge(%{method: "PATCH"})
    params = %{"id" => "#{id}", "name" => name(0)}
    res = RC.update(conn, params)

    assert res.status === 200 and String.contains?(res.resp_body, name(0))
  end

  test "update preferred vsn" do
    ext(0) |> Remote.external_update()
    id = Remote.all() |> hd() |> Map.get(:id, 0)

    conn = build_conn() |> Map.merge(%{method: "PATCH"})
    params = %{"id" => "#{id}", "preferred_vsn" => "head"}
    res = RC.update(conn, params)

    assert res.status === 200 and String.contains?(res.resp_body, "head")
  end

  test "delete by id" do
    ext(1) |> Remote.external_update()
    id = Remote.all() |> hd() |> Map.get(:id, 0)

    conn = build_conn()
    params = %{"id" => "#{id}"}
    res = RC.delete(conn, params)

    assert res.resp_body === "{\"rows\":1}"
  end

  test "index" do
    ext(1) |> Remote.external_update()

    conn = build_conn()
    params = %{}
    res = RC.index(conn, params)
    {rc, json} = Jason.decode(res.resp_body)

    assert rc === :ok and Map.has_key?(json, "data") and Map.has_key?(json, "items")
  end
end
