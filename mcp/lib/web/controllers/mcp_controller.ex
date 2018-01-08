defmodule Web.McpController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  def index(conn, _params) do
    # switch_fnames = Switch.all(:names)
    # sensor_fnames = Sensor.all(:names)
    all_mts = Mixtank.all()

    mts = for mt <- all_mts do
      profiles = for p <- mt.profiles do
        p.name
      end

      active = for p <- mt.profiles, p.active, do: p.name

      %{mixtank: mt.name, profiles: profiles, active: active}
    end

    render conn, "index.html",
      #switch_fnames: switch_fnames,
      #switch_fnames_count: Enum.count(switch_fnames),
      #sensor_fnames: sensor_fnames,
      #sensor_fnames_count: Enum.count(sensor_fnames),
      mixtanks: mts,
      current_user: get_session(conn, :current_user)
  end

end
