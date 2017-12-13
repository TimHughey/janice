defmodule Web.McpController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  alias Mcp.DevAlias
  alias Mcp.Sensor
  alias Mcp.Switch

  def index(conn, _params) do
    all_fnames = DevAlias.all(:friendly_names) |> MapSet.new()
    switch_fnames = Switch.all(:friendly_names)
    sensor_fnames = Sensor.all(:friendly_names)

    known_fnames = (switch_fnames ++ sensor_fnames) |> MapSet.new()
    unknown_fnames =
      MapSet.difference(all_fnames, known_fnames) |> Enum.sort()

    render conn, "index.html",
      all_fnames_count: Enum.count(all_fnames),
      switch_fnames: switch_fnames,
      switch_fnames_count: Enum.count(switch_fnames),
      sensor_fnames: sensor_fnames,
      sensor_fnames_count: Enum.count(sensor_fnames),
      unknown_fnames: unknown_fnames,
      unknown_fnames_count: Enum.count(unknown_fnames),
      current_user: get_session(conn, :current_user)
  end

end
