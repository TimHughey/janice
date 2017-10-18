defmodule ApiWeb.McpController do
  use ApiWeb, :controller
  
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
      unknown_fnames_count: Enum.count(unknown_fnames) 
  end

  def show(conn, %{"fname" => fname}) do

    %DevAlias{device: device,
              last_seen_at: last_seen} = DevAlias.get_by_friendly_name(fname)

    if Switch.is_switch?(fname) do
      render conn, "switch.html",
        fname: fname, device: device, last_seen: last_seen,
        state: Switch.get_state(fname) 
    else
      render conn, "sensor.html",
        fname: fname, device: device, last_seen: last_seen,
        fahrenheit: Sensor.fahrenheit(fname),
        relhum: Sensor.relhum(fname) 

    end
  end
end
