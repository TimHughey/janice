defmodule Web.McpDetailController do
  @moduledoc """
  """
  require Logger

  use Timex
  use Web, :controller

  alias Mcp.DevAlias
  alias Mcp.Sensor
  alias Mcp.Switch

  def index(conn, %{"type" => "alias-only"} = params) do
    Logger.info fn -> inspect(params) end

    all_fnames = DevAlias.all(:friendly_names) |> MapSet.new()
    switch_fnames = Switch.all(:friendly_names)
    sensor_fnames = Sensor.all(:friendly_names)

    known_fnames = (switch_fnames ++ sensor_fnames) |> MapSet.new()
    unknown_fnames =
      MapSet.difference(all_fnames, known_fnames) |> Enum.sort()

    unknown = Enum.map(unknown_fnames, fn(x) -> dev_alias_details(x) end)

    render conn, "index.json", mcp_details: unknown
  end

  def index(conn, %{"type" => "switches"} = params) do
    Logger.info fn -> inspect(params) end

    switch_fnames = Switch.all(:friendly_names)

    switches = Enum.map(switch_fnames, fn(x) -> switch_details(x) end)

    render conn, "index.json", mcp_details: switches
  end

  def index(conn, %{"type" => "sensors"} = params) do
    Logger.info fn -> inspect(params) end
    Logger.info fn -> inspect(conn) end

    sensor_fnames = Sensor.all(:friendly_names)
    sensors = Enum.map(sensor_fnames, fn(x) -> sensor_details(x) end)

    render conn, "index.json", mcp_details: sensors
  end

  defp dev_alias_details(fname) do
    DevAlias.get_by_friendly_name(fname)
  end

  defp switch_details(fname) do
    dev_alias = DevAlias.get_by_friendly_name(fname)
    switch = Switch.get(:friendly_name, fname)

    %{a: dev_alias, s: switch}
  end

  defp sensor_details(fname) do
    dev_alias = DevAlias.get_by_friendly_name(fname)
    sensor = Sensor.get(:friendly_name, fname)

    %{a: dev_alias, s: sensor}
  end

end
