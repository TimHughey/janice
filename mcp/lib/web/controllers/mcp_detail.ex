defmodule Web.McpDetailController do
  @moduledoc """
  """
  require Logger

  use Timex
  use Web, :controller

  def index(conn, %{"type" => "switches"} = params) do
    Logger.info fn -> inspect(params) end

    switches = SwitchState.all(:everything)

    render conn, "index.json", mcp_details: switches
  end

  def index(conn, %{"type" => "sensors"} = params) do
    Logger.info fn -> inspect(params) end
    Logger.debug fn -> inspect(conn) end

    sensors = Sensor.all(:everything)

    render conn, "index.json", mcp_details: sensors
  end

end
