defmodule Web.AngularController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  def index(conn, _params) do
    conn
    |> put_layout("angular.html")
    |> render("index.html", current_user: get_session(conn, :current_user))
  end
end
