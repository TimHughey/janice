defmodule Web.McpDetailController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  alias Mcp.DevAlias
  alias Mcp.Sensor
  alias Mcp.Switch

  def index(conn, %{"type" => "unknowns"}) do
    all_fnames = DevAlias.all(:friendly_names) |> MapSet.new()
    switch_fnames = Switch.all(:friendly_names)
    sensor_fnames = Sensor.all(:friendly_names)

    known_fnames = (switch_fnames ++ sensor_fnames) |> MapSet.new()
    unknown_fnames =
      MapSet.difference(all_fnames, known_fnames) |> Enum.sort()

    unknown = Enum.map(unknown_fnames, fn(x) -> dev_alias_details(x) end)

    render conn, "index.json", mcp_details: unknown
  end

  defp dev_alias_details(fname) do
    DevAlias.get_by_friendly_name(fname)
  end

end
