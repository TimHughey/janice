defmodule WebRemoteControllerTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  use Web.ConnCase
  use Timex

  alias Web.RemoteController, as: Controller

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

  test "delete by id" do
    num = 2
    ext(num) |> Remote.external_update()
    id = Remote.get_by(host: host(num)) |> Map.get(:id)

    conn = build_conn()
    params = %{"id" => "#{id}"}
    res = Controller.delete(conn, params)

    assert res.resp_body === "{\"rows\":1}"
  end

  test "index" do
    num = 3
    ext(num) |> Remote.external_update()

    conn = build_conn()
    params = %{}
    res = Controller.index(conn, params)
    {rc, json} = Jason.decode(res.resp_body)

    assert rc === :ok
    assert Map.has_key?(json, "data")
    assert Map.has_key?(json, "items")
  end

  test "ota all (no log)" do
    num = 4
    ext(num) |> Remote.external_update()

    conn = build_conn() |> Map.merge(%{method: "GET"})
    params = %{"ota_all" => "true", log: false}
    res = Controller.index(conn, params)

    assert res.status === 200
    assert String.contains?(res.resp_body, "ota_all")
    assert String.contains?(res.resp_body, "ok")
  end

  test "ota all (with log)" do
    num = 4
    ext(num) |> Remote.external_update()

    conn = build_conn() |> Map.merge(%{method: "GET"})
    params = %{"ota_all" => "true", log: true}
    msg = capture_log(fn -> Controller.index(conn, params) end)

    assert msg =~ "needs update"
  end

  test "restart trigger" do
    num = 5
    ext(num) |> Remote.external_update()
    id = Remote.get_by(host: host(num)) |> Map.get(:id)

    conn = build_conn() |> Map.merge(%{method: "PATCH"})
    params = %{"id" => "#{id}", "restart" => true}
    res = Controller.update(conn, params)

    assert res.status === 200
    assert String.contains?(res.resp_body, "restart")
    assert String.contains?(res.resp_body, "ok")
  end

  test "update name" do
    num = 0
    name = name(num)
    ext(num) |> Remote.external_update()
    id = Remote.get_by(host: host(num)) |> Map.get(:id)

    conn = build_conn() |> Map.merge(%{method: "PATCH"})
    params = %{"id" => "#{id}", "name" => name}
    res = Controller.update(conn, params)

    assert res.status === 200
    assert String.contains?(res.resp_body, name)
  end

  test "update preferred vsn" do
    num = 1
    ext(num) |> Remote.external_update()
    id = Remote.get_by(host: host(num)) |> Map.get(:id)

    conn = build_conn() |> Map.merge(%{method: "PATCH"})
    params = %{"id" => "#{id}", "preferred_vsn" => "head"}
    res = Controller.update(conn, params)

    assert res.status === 200
    assert String.contains?(res.resp_body, "head")
  end
end
