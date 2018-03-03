defmodule Web.AuthController do
  require Logger
  use Web, :controller
  plug(Ueberauth)

  # alias Ueberauth.Strategy.Helpers
  alias Web.UserFromAuth
  alias Web.Guardian.Plug

  # def callback_url(conn) do
  #   Helpers.callback_url(conn)
  # end

  def request(conn, _params) do
    render(conn, "request.html")
  end

  def delete(conn, _params) do
    case Plug.current_resource(conn) do
      nil ->
        conn
        |> configure_session(drop: true)
        |> put_flash(:error, "no current user")
        |> redirect(to: "/janice")

      resource ->
        conn
        |> configure_session(drop: true)
        |> put_flash(:info, "#{resource} logged out!")
        |> redirect(to: "/janice")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    Logger.warn(fn -> "Auth Failure Map: " <> inspect(fails) end)

    conn
    |> put_flash(:error, "Ueberauth failure")
    |> redirect(to: "/janice")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    Logger.info(fn -> "Auth Map:" end)
    Logger.info(fn -> inspect(auth) end)
    Logger.info(fn -> "#{auth.provider} success for #{auth.uid}" end)

    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        conn
        |> Plug.sign_in(user)
        |> clear_flash()
        |> put_flash(:info, "Welcome #{user.name}")
        |> put_session(:current_user, user)
        |> redirect(to: "/janice")

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: "/janice")
    end
  end
end
