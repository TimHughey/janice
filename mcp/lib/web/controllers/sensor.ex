defmodule Web.SensorController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def delete(conn, %{"id" => id}) do
    Logger.info fn -> ~s(DELETE #{conn.request_path}) end

    {rows, _} = Sensor.delete(String.to_integer(id))

    json(conn, %{rows: rows})
  end

end
