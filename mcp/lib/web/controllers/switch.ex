defmodule Web.SwitchController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def delete(conn, %{"id" => id}) do
    Logger.info fn -> ~s(DELETE #{conn.request_path}) end

    {rows, _} = SwitchState.delete(String.to_integer(id))

    json(conn, %{rows: rows})
  end

  def update(%{method: "PATCH"} = conn,
    %{"id" => id, "name" => new_name} = _params) do

    Logger.info fn -> ~s(#{conn.method} #{conn.request_path}) end

    SwitchState.change_name(String.to_integer(id), new_name, "changed via web")

    json(conn, %{name: new_name})
  end

  def update(%{method: "PATCH"} = conn,
    %{"id" => id, "toggle" => "true"} = _params) do

    Logger.info fn -> ~s(#{conn.method} #{conn.request_path}) end

    new_state = SwitchState.toggle(String.to_integer(id))

    json(conn, %{state: new_state})
  end

end
