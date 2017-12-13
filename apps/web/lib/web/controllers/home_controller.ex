defmodule Web.HomeController do
  require Logger
  use Web, :controller

  alias Web.AuthController
  alias Web.Guardian.Plug

  def index(conn, _params) do
    # Logger.info fn -> inspect(conn) end
    Logger.info fn ->
      resource = Plug.current_resource(conn) |> inspect
      "resource: #{resource}"
    end

    render conn, "index.html",
      current_user: get_session(conn, :current_user),
      callback_url: AuthController.callback_url(conn)
  end
end
