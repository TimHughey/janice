defmodule Web.AuthErrorHandler do
  @moduledoc """
  """
  require Logger
  use Web, :controller
  import Plug.Conn
  import Web.Router.Helpers

  def auth_error(conn, {:invalid_token = type, :invalid_issuer = reason}, opts) do
    Logger.info(fn -> "type: #{inspect(type)} reason: #{inspect(reason)}" end)
    Logger.info(fn -> "opts: #{inspect(opts)}" end)

    conn
    |> configure_session(drop: true)
    |> put_flash(:error, "Invalid token, session cleared")
    |> redirect(to: home_path(conn, :index))
  end

  def auth_error(conn, {type, reason}, opts) do
    # Logger.info fn -> inspect(conn) end
    Logger.info(fn -> "type: #{inspect(type)} reason: #{inspect(reason)}" end)
    Logger.info(fn -> "opts: #{inspect(opts)}" end)

    # body = Poison.encode!(%{message: to_string(type)})
    # send_resp(conn, 401, body)

    unauthenticated(conn, opts)
  end

  def unauthenticated(conn, _opts) do
    # Logger.info fn -> inspect(conn) end
    conn
    |> put_flash(:error, "Please log in to access that page.")
    |> redirect(to: home_path(conn, :index))
  end
end
