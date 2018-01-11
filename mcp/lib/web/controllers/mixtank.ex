defmodule Web.MixtankController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def manage(conn, %{"action" => "change_profile"} = params) do
    Logger.info fn -> "#{inspect(params)}" end
    mixtank = Map.get(params, "mixtank")
    profile = Map.get(params, "profile")
    Mixtank.Control.activate_profile(mixtank, profile)
    active_profile = Mixtank.active_profile(mixtank, :name)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{active_profile: active_profile}))

    # render conn, "index.json", params
  end

  def all(conn, params) do
    Logger.info fn -> "#{inspect(params)}" end

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
