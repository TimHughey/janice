defmodule ApiWeb.SwitchControllerTest do
  use ApiWeb.ConnCase

  alias Api.Mcp
  alias Api.Mcp.Switch

  @create_attrs %{id: 42}
  @update_attrs %{id: 43}
  @invalid_attrs %{id: nil}

  def fixture(:switch) do
    {:ok, switch} = Mcp.create_switch(@create_attrs)
    switch
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all switches", %{conn: conn} do
      conn = get conn, switch_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create switch" do
    test "renders switch when data is valid", %{conn: conn} do
      conn = post conn, switch_path(conn, :create), switch: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, switch_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "id" => 42}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, switch_path(conn, :create), switch: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update switch" do
    setup [:create_switch]

    test "renders switch when data is valid", %{conn: conn, switch: %Switch{id: id} = switch} do
      conn = put conn, switch_path(conn, :update, switch), switch: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, switch_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "id" => 43}
    end

    test "renders errors when data is invalid", %{conn: conn, switch: switch} do
      conn = put conn, switch_path(conn, :update, switch), switch: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete switch" do
    setup [:create_switch]

    test "deletes chosen switch", %{conn: conn, switch: switch} do
      conn = delete conn, switch_path(conn, :delete, switch)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, switch_path(conn, :show, switch)
      end
    end
  end

  defp create_switch(_) do
    switch = fixture(:switch)
    {:ok, switch: switch}
  end
end
