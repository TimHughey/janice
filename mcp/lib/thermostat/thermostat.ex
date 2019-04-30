defmodule Thermostat do
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
    Thermostat schema
  """

  require Logger
  use Ecto.Schema

  import Repo, only: [one: 1, insert_or_update!: 1]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Janice.TimeSupport

  alias Thermostat.Profile

  schema "thermostat" do
    field(:name)
    field(:description)
    field(:owned_by)
    field(:enable, :boolean)
    field(:switch)
    field(:active_profile)
    field(:sensor)
    field(:state)
    field(:state_at, :utc_datetime_usec)
    field(:log_activity, :boolean)

    has_many(:profiles, Profile)

    timestamps()
  end

  # 15 minutes (as millesconds)
  @delete_timeout_ms 15 * 60 * 1000

  # quietly handle requests to activate a profile that is already active
  def activate_profile(%Thermostat{active_profile: active} = t, profile)
      when is_binary(profile) and active === profile,
      do: {:ok, t}

  def activate_profile(%Thermostat{} = t, profile) when is_binary(profile) do
    if Profile.known?(t, profile) do
      {rc, ct} = change(t, active_profile: profile) |> Repo.update()

      if rc === :ok, do: {rc, Repo.preload(ct, :profiles)}, else: {rc, t}
    else
      {:unknown_profile, t}
    end
  end

  def add([]), do: []

  def add([%Thermostat{} = th | rest]) do
    [add(th)] ++ add(rest)
  end

  def add(%Thermostat{name: name} = th) do
    q = from(t in Thermostat, where: t.name == ^name, select: {t})

    case one(q) do
      nil ->
        th |> change([]) |> insert_or_update!() |> Thermostat.Server.start_server()

      found ->
        Logger.warn(fn -> "add() [#{th.name}] already exists" end)
        found
    end
  end

  # all() function header
  def all(atom, opts \\ [])

  def all(:ids, opts) when is_list(opts) do
    for t <- Repo.all(Thermostat), do: Map.get(t, :id)
  end

  def delete_all(:dangerous) do
    names = from(t in Thermostat, select: t.name) |> Repo.all(timeout: @delete_timeout_ms)

    for name <- names do
      rc = Thermostat.Server.shutdown(name)
      {name, rc}
    end

    from(t in Thermostat, where: t.id >= 0) |> Repo.delete_all()
  end

  def enable(%Thermostat{} = t, val) when is_boolean(val) do
    {rc, ct} = change(t, enable: val) |> Repo.update()

    if rc === :ok, do: {rc, Repo.preload(ct, :profiles)}, else: {rc, ct}
  end

  def enabled?(%Thermostat{enable: enable}), do: enable

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :device, :name])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      th =
        from(
          t in Thermostat,
          join: p in assoc(t, :profiles),
          where: ^filter,
          preload: [profiles: p]
        )
        |> one()

      if is_nil(th) or Enum.empty?(select), do: th, else: Map.take(th, select)
    end
  end

  def log?(%Thermostat{log_activity: log}), do: log

  def owner(%Thermostat{} = t, opts \\ []) when is_list(opts) do
    cond do
      t.owned_by === "none" -> :none
      is_nil(t.owned_by) -> :standalone
      true -> t.owned_by
    end
  end

  def profiles(%Thermostat{} = t, opts \\ []) when is_list(opts) do
    active = opts[:active] || false
    names = opts[:names] || false

    cond do
      active and not is_nil(t.active_profile) -> t.active_profile
      active and is_nil(t.active_profile) -> :none
      names -> Profile.names(t)
      true -> t.profiles
    end
  end

  def release_ownership(%Thermostat{} = t, opts \\ []) when is_list(opts) do
    log = opts[:log] || false

    log && Logger.warn(fn -> "thermostat [#{t.name}] ownership released" end)

    change(t, owned_by: "none") |> Repo.update()
  end

  def state(%Thermostat{state: curr_state}), do: curr_state

  def state(%Thermostat{} = t, new_state) when is_binary(new_state) do
    {rc, ct} = change(t, state: new_state, state_at: TimeSupport.utc_now()) |> Repo.update()

    if rc === :ok, do: {rc, Repo.preload(ct, :profiles)}, else: {rc, t}
  end

  def standalone(%Thermostat{} = t, opts \\ [])
      when is_list(opts) do
    log = opts[:log] || false

    log && Logger.warn(fn -> "thermostat [#{t.name}] now standalone" end)

    {rc, ct} = change(t, owned_by: nil) |> Repo.update()

    if rc === :ok, do: {rc, Repo.preload(ct, :profiles)}, else: {rc, t}
  end

  def standalone?(%Thermostat{} = t, opts \\ []) when is_list(opts) do
    if is_nil(t.owned_by), do: true, else: false
  end

  def switch(%Thermostat{switch: sw}), do: sw

  def take_ownership(%Thermostat{} = t, owner, opts \\ [])
      when is_binary(owner) and is_list(opts) do
    log = opts[:log] || false

    log && Logger.warn(fn -> "thermostat [#{t.name}] owned by #{owner}" end)

    change(t, owned_by: owner) |> Repo.update()
  end
end
