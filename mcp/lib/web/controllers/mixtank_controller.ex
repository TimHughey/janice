defmodule Web.MixtankController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def update(%{method: "PATCH"} = conn, %{"id" => id_str, "newProfile" => profile} = _params)
      when is_binary(id_str) do
    id = String.to_integer(id_str)
    Mixtank.Control.activate_profile(id, profile)
    active_profile = Mixtank.active_profile(id, :name)

    json(conn, %{active_profile: active_profile})
  end

  def index(conn, _params) do
    mixtanks = Mixtank.all()

    data =
      for mt <- mixtanks do
        map = Mixtank.as_map(mt) |> Map.put_new(:type, "mixtank")

        state =
          Map.put_new(map.state, :started_at_secs, to_seconds(map.state.started_at))
          |> Map.put_new(:state_at_secs, to_seconds(map.state.state_at))

        profile_names = for p <- map.profiles, do: p.name

        map |> Map.put(:state, state) |> Map.put(:profile_names, profile_names)
      end

    resp = %{data: data, items: Enum.count(data), mtime: Timex.local() |> Timex.to_unix()}

    json(conn, resp)
  end

  defp to_seconds(dt) do
    if is_nil(dt), do: nil, else: Timex.diff(Timex.now(), dt, :seconds)
  end
end
