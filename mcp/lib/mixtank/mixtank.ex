defmodule Mixtank do
  @moduledoc """
  """

  @vsn 4

  require Logger
  use GenServer
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  import Repo, only: [all: 1, one: 1, insert_or_update!: 1, update_all: 2]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Mixtank.Profile

  schema "mixtank" do
    field :name
    field :comment
    field :enable, :boolean, default: false
    field :sensor
    field :ref_sensor
    field :pump
    field :air
    field :heater
    field :fill
    field :replenish
    has_one :state, Mixtank.State
    has_many :profiles, Mixtank.Profile

    timestamps usec: true
  end

  def add([]), do: []
  def add([%Mixtank{} = mt | rest]) do
    [add(mt)] ++ add(rest)
  end

  def add(%Mixtank{name: name} = mt) do
    q = from(mt in Mixtank, where: mt.name == ^name, select: {mt})

    case one(q) do
      nil   -> change(mt, []) |> insert_or_update!()
      found -> Logger.warn ~s/add() [#{name}] already exists/
               found
    end
  end

  def all do
    from(mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      preload: [profiles: p, state: s],
      select: mt) |> all()
  end

  def all_active do
    from(mt in Mixtank,
      join: p in assoc(mt, :profiles), where: p.active == true,
      join: s in assoc(mt, :state),
      preload: [profiles: p, state: s],
      select: mt) |> all()
  end

  def activate_profile(mt_name, profile_name)
  when is_binary(mt_name) and is_binary(profile_name) do
    mt = from(mt in Mixtank,
               where: mt.name == ^mt_name) |> one()

    if mt != nil,
      do: Profile.activate(mt, profile_name),
    else: Logger.warn fn -> "mixtank [#{mt_name}] does not " <>
                                   "exist, can't activate profile" end
  end

  def active_profile(name, :name) do
    active_profile(name)
    |> Map.get(:profiles)
    |> hd()
    |> Map.get(:name)
  end

  def active_profile(name) do
    from(mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      where: p.active == true,
      where: mt.name == ^name,
      select: mt,
      preload: [state: s, profiles: p]) |> one()
  end

  def available_profiles(name) when is_binary(name) do
    from(mt in Mixtank,
          join: p in assoc(mt, :profiles),
          where: mt.name == ^name,
          select: p.name) |> all()
  end

  def disable(%Mixtank{name: name}), do: disable(name)
  def disable(name) when is_binary(name) do
    from(mt in Mixtank,
          where: mt.name == ^name,
          update: [set: [enable: false]]) |> update_all([])
  end

  def enable(name) when is_binary(name) do
    from(mt in Mixtank,
          where: mt.name == ^name,
          update: [set: [enable: true]]) |> update_all([])
  end

  def get(name) do
    from(mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      where: mt.name == ^name,
      select: mt,
      preload: [state: s, profiles: p]) |> one()
  end
end
