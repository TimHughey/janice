defmodule Web.AuthController do

  use Web, :controller
  plug Ueberauth

  alias Ueberauth.Strategy.Helpers
  alias Web.UserFromAuth
  alias Web.Guardian
  alias Web.Guardian.Plug

  def callback_url(conn) do
    Helpers.callback_url(conn)
  end

  def request(conn, _params) do
    render(conn, "request.html")
  end

  def delete(conn, _params) do
    case Plug.current_resource(conn) do
      nil       -> conn
                    |> configure_session(drop: true)
                    |> put_flash(:error, "no current user")
                    |> redirect(to: "/mercurial")

      resource  -> conn
                    |> configure_session(drop: true)
                    |> put_flash(:info, "#{resource} logged out!")
                    |> redirect(to: "/mercurial")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
      |> put_flash(:error, "Failed to authenticate.")
      |> redirect(to: "/mercurial")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user}      -> conn
                           |> Plug.sign_in(user)
                           |> clear_flash()
                           |> put_flash(:info, "Welcome #{user.id}")
                           |> put_session(:current_user, user)
                           |> redirect(to: "/mercurial")

      {:error, reason} -> conn
                           |> put_flash(:error, reason)
                           |> redirect(to: "/mercurial")
    end
  end
end
