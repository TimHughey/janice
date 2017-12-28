defmodule Web.McpController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  def index(conn, _params) do
    switch_fnames = Switch.all(:names)
    sensor_fnames = Sensor.all(:names)

    render conn, "index.html",
      switch_fnames: switch_fnames,
      switch_fnames_count: Enum.count(switch_fnames),
      sensor_fnames: sensor_fnames,
      sensor_fnames_count: Enum.count(sensor_fnames),
      current_user: get_session(conn, :current_user)
  end

end
