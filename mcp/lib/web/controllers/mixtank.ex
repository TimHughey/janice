defmodule Web.MixtankController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def update(%{method: "PATCH"} = conn, %{"id" => mixtank, "newprofile" => profile} = params)
  when is_binary(mixtank) do
    Logger.info fn -> ~s(#{conn.method} #{conn.request_path}) end

    Mixtank.Control.activate_profile(mixtank, profile)
    active_profile = Mixtank.active_profile(mixtank, :name)

    json(conn, %{active_profile: active_profile})
  end

  def index(conn, _params) do
    Logger.info fn -> ~s(INDEX #{conn.request_path}) end

    all_mts = Mixtank.all()

    mts = for mt <- all_mts do
      profiles = for p <- mt.profiles do
        p.name
      end

      %{mixtank: mt.name, profiles: profiles}
    end

    render conn, "all.json", %{all: mts}
  end
end
