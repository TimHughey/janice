defmodule Web.SensorController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def manage(conn, %{"action" => "delete", "name" => name} = params) do
    Logger.info fn -> inspect(params) end

    Sensor.delete(name)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "{}")
  end
end
