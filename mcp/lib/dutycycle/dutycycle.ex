defmodule Dutycycle do
  #    Master Control Program for Wiss Landing
  #    Copyright (C) 2016  Tim Hughey (thughey)

  #    This program is free software: you can redistribute it and/or modify
  #    it under the terms of the GNU General Public License as published by
  #    the Free Software Foundation, either version 3 of the License, or
  #    (at your option) any later version.

  #    This program is distributed in the hope that it will be useful,
  #    but WITHOUT ANY WARRANTY; without even the implied warranty of
  #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  #    GNU General Public License for more details.

  #    You should have received a copy of the GNU General Public License
  #    along with this program.  If not, see <http://www.gnu.org/licenses/>

  @moduledoc """
    Dutycycle schema
  """

  require Logger
  use Ecto.Schema

  import Repo, only: [one: 1, insert_or_update!: 1, update: 1]
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  import Janice.Common.DB, only: [name_regex: 0]

  alias Dutycycle.Profile
  alias Dutycycle.State

  schema "dutycycle" do
    field(:name)
    field(:comment)
    field(:enable, :boolean)
    field(:standalone, :boolean)
    field(:log, :boolean)
    field(:device)
    has_one(:state, State)
    has_many(:profiles, Profile)

    timestamps(usec: true)
  end

  # 15 minutes (as millesconds)
  @delete_timeout_ms 15 * 60 * 1000

  def activate(opts) when is_list(opts) do
    name = Keyword.get(opts, :name)
    profile = Keyword.get(opts, :profile)

    if is_nil(name) or is_nil(profile) do
      :not_found
    else
    end
  end

  def add([]), do: []

  def add([%Dutycycle{} = dc | rest]) do
    [add(dc)] ++ add(rest)
  end

  def add(%Dutycycle{name: name} = dc) do
    q = from(d in Dutycycle, where: d.name == ^name, select: {d})

    case one(q) do
      nil ->
        dc = Map.put(dc, :state, %State{}) |> change([]) |> insert_or_update!()
        Dutycycle.Server.start_server(dc)

      found ->
        Logger.warn(~s/add() [#{dc.name}] already exists/)
        found
    end
  end

  # FUNCTION HEADER
  def all(atom, opts \\ [])

  def all(:ids, opts) when is_list(opts) do
    for d <- Repo.all(Dutycycle), do: Map.get(d, :id)
  end

  def all(:names, opts) when is_list(opts) do
    for d <- Repo.all(Dutycycle), do: Map.get(d, :name)
  end

  # LEGACY
  def all_active do
    from(
      d in Dutycycle,
      join: p in assoc(d, :profiles),
      where: p.active == true,
      join: s in assoc(d, :state),
      preload: [profiles: p, state: s],
      select: d
    )
    |> Repo.all()
  end

  def as_map(nil), do: %{}

  def as_map(%Dutycycle{} = dc) do
    %{
      id: dc.id,
      name: dc.name,
      comment: dc.comment,
      enable: dc.enable,
      standalone: dc.standalone,
      device: dc.device,
      profiles: Profile.as_map(dc.profiles),
      state: State.as_map(dc.state)
    }
  end

  def delete_all(:dangerous) do
    names =
      from(d in Dutycycle, select: d.name)
      |> Repo.all(timeout: @delete_timeout_ms)

    for name <- names do
      rc = Dutycycle.Server.shutdown(name)
      {name, rc}
    end

    from(dc in Dutycycle, where: dc.id >= 0)
    |> Repo.delete_all()
  end

  def device_change(%Dutycycle{} = d, new_device) when is_binary(new_device) do
    # reload the Dutycycle to be safe
    dc = reload(d)

    update(dc, device: new_device)
  end

  def device_change(d, device) do
    Logger.warn(fn ->
      "invalid args: device_change(#{inspect(d)}, #{inspect(device)}"
    end)

    {:error, :invalid_args}
  end

  def changeset(dc, params \\ %{}) do
    dc
    |> cast(params, possible_changes())
    |> validate_required(possible_changes())
    |> validate_format(:name, name_regex())
    |> validate_format(:standalone, &is_boolean/1)
  end

  def enable(%Dutycycle{} = dc, val) when is_boolean(val) do
    change(dc, enable: val) |> Repo.update()
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :device, :name])

    select =
      Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      dc =
        from(
          d in Dutycycle,
          join: p in assoc(d, :profiles),
          join: s in assoc(d, :state),
          where: ^filter,
          preload: [state: s, profiles: p]
        )
        |> one()

      if is_nil(dc) or Enum.empty?(select), do: dc, else: Map.take(dc, select)
    end
  end

  defp possible_changes, do: [:name, :comment, :device, :standalone]

  def profiles(%Dutycycle{} = d, opts \\ []) when is_list(opts) do
    only_active = Keyword.get(opts, :only_active, false)

    if only_active do
      list = for p <- d.profiles, p.active, do: p.name
      if Enum.empty?(list), do: :none, else: hd(list)
    else
      for p <- d.profiles, do: %{profile: p.name, active: p.active}
    end
  end

  def reload(%Dutycycle{id: id}), do: Repo.get(Dutycycle, id)

  def standalone(%Dutycycle{} = dc, val) when is_boolean(val),
    do: update(dc, standalone: val)

  def standalone?(%Dutycycle{} = d), do: d.standalone

  def update(name, opts) when is_binary(name) and is_list(opts),
    do: get_by(name: name) |> update(opts)

  def update(%Dutycycle{} = dc, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(dc, set)

    if cs.valid? do
      update(cs)
    else
      {:invalid_changes, cs}
    end
  end

  def update(nil, _opts), do: {:error, :not_found}
end
