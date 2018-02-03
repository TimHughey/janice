defmodule Web.HomeController do
  require Logger
  use Web, :controller

  alias Web.Guardian.Plug

  def index(conn, _params) do
    # Logger.info fn -> inspect(conn) end
    resource = Plug.current_resource(conn)

    resource &&
      Logger.info(fn ->
        r = Plug.current_resource(conn)
        c = Plug.current_claims(conn)
        "resource: #{inspect(r)} claims: #{inspect(c)}"
      end)

    render(conn, "index.html", current_user: get_session(conn, :current_user))
    #
  end
end
