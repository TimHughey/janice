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
  GenServer implementation of Dutycycle controller capable of:
    - controlling a single device
    - to maintain temperature in alignment with reference
  """

  require Logger
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  import Repo, only: [all: 1, one: 1, insert_or_update!: 1, update_all: 2]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Dutycycle.Profile
  alias Dutycycle.State

  @vsn 3

  schema "dutycycle" do
    field(:name)
    field(:comment)
    field(:enable, :boolean)
    field(:log, :boolean)
    field(:device)
    has_one(:state, State)
    has_many(:profiles, Profile)

    timestamps(usec: true)
  end

  def add([]), do: []

  def add([%Dutycycle{} = dc | rest]) do
    [add(dc)] ++ add(rest)
  end

  def add(%Dutycycle{name: name} = dc) do
    q = from(d in Dutycycle, where: d.name == ^name, select: {d})

    case one(q) do
      nil ->
        change(dc, []) |> insert_or_update!()

      found ->
        Logger.warn(~s/add() [#{dc.name}] already exists/)
        found
    end
  end

  def all do
    from(
      d in Dutycycle,
      join: p in assoc(d, :profiles),
      join: s in assoc(d, :state),
      preload: [profiles: p, state: s],
      select: d
    )
    |> all()
  end

  def all_active do
    from(
      d in Dutycycle,
      join: p in assoc(d, :profiles),
      where: p.active == true,
      join: s in assoc(d, :state),
      preload: [profiles: p, state: s],
      select: d
    )
    |> all()
  end

  def activate_profile(dc_name, profile_name, opts \\ :none)
      when is_binary(dc_name) and is_binary(profile_name) do
    dc = from(d in Dutycycle, where: d.name == ^dc_name) |> one()

    if opts == :enable, do: enable(dc_name)

    if dc != nil,
      do: Profile.activate(dc, profile_name),
      else:
        Logger.warn(fn ->
          "dutycycle [#{dc_name}] does not " <> "exist, can't activate profile"
        end)
  end

  def active_profile(name) do
    from(
      d in Dutycycle,
      join: m in assoc(d, :profiles),
      join: s in assoc(d, :state),
      where: m.active == true,
      where: d.name == ^name,
      select: d,
      preload: [state: s, profiles: m]
    )
    |> one()
  end

  def available_profiles(name) when is_binary(name) do
    from(
      d in Dutycycle,
      join: p in assoc(d, :profiles),
      where: d.name == ^name,
      select: p.name
    )
    |> all()
  end

  def disable(name) when is_binary(name) do
    from(
      d in Dutycycle,
      where: d.name == ^name,
      update: [set: [enable: false]]
    )
    |> update_all([])
  end

  def enable(name) when is_binary(name) do
    from(
      d in Dutycycle,
      where: d.name == ^name,
      update: [set: [enable: true]]
    )
    |> update_all([])
  end

  def get(name) do
    from(
      d in Dutycycle,
      join: p in assoc(d, :profiles),
      join: s in assoc(d, :state),
      where: d.name == ^name,
      select: d,
      preload: [state: s, profiles: p]
    )
    |> one()
  end
end
