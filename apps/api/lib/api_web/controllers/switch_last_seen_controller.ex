defmodule ApiWeb.SwitchesLastSeenController do
  use ApiWeb, :controller

  import Mcp.Switch, only: [all: 0]

  def index(conn, _params) do
    switches = all()
    render conn, "index.json", switches: switches 
  end
end
