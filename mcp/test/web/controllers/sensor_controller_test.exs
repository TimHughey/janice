defmodule WebSensorControllerTest do
  @moduledoc false

  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  import JanTest
  use Web.ConnCase

  alias Web.SensorController, as: Controller

  setup_all do
    for n <- 0..10, do: relhum_ext_msg(n)

    :ok
  end

  @tag :web_controller
  test "index page" do
    conn = build_conn()
    params = %{}

    res = Controller.index(conn, params)
    {rc, json} = Jason.decode(res.resp_body)

    assert rc === :ok
    assert Map.has_key?(json, "data")
    assert Map.has_key?(json, "items")
  end

  test "delete a sensor by id" do
    delete_id = Sensor.get_by(device: relhum_dev(10)) |> Map.get(:id)
    conn = build_conn() |> Map.put(:method, "PATCH")
    params = %{"id" => "#{delete_id}"}

    res = Controller.delete(conn, params)

    assert res.resp_body === "{\"rows\":1}"
  end

  test "change the name of a sensor" do
    num = 9
    change_id = Sensor.get_by(device: relhum_dev(num)) |> Map.get(:id)
    conn = build_conn() |> Map.put(:method, "PATCH")
    name = relhum_name(num)
    params = %{"id" => "#{change_id}", "name" => name}

    res = Controller.update(conn, params)

    assert res.status === 200
    assert String.contains?(res.resp_body, name)
  end
end
