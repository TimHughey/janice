defmodule Mixtank do
  @moduledoc """
  """

  @vsn 4

  require Logger
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  import Repo, only: [all: 1, one: 1, insert_or_update!: 1, update_all: 2]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Mixtank.Profile
  alias Mixtank.State

  schema "mixtank" do
    field(:name)
    field(:comment)
    field(:enable, :boolean, default: false)
    field(:sensor)
    field(:ref_sensor)
    field(:pump)
    field(:air)
    field(:heater)
    field(:fill)
    field(:replenish)
    has_one(:state, Mixtank.State)
    has_many(:profiles, Mixtank.Profile)

    timestamps(usec: true)
  end

  def add([]), do: []

  def add([%Mixtank{} = mt | rest]) do
    [add(mt)] ++ add(rest)
  end

  def add(%Mixtank{name: name} = mt) do
    q = from(mt in Mixtank, where: mt.name == ^name, select: {mt})

    case one(q) do
      nil ->
        change(mt, []) |> insert_or_update!()

      found ->
        Logger.warn(~s/add() [#{name}] already exists/)
        found
    end
  end

  def all do
    from(
      mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      preload: [profiles: p, state: s],
      select: mt
    )
    |> all()
  end

  def all_active do
    from(
      mt in Mixtank,
      join: p in assoc(mt, :profiles),
      where: p.active == true,
      join: s in assoc(mt, :state),
      preload: [profiles: p, state: s],
      select: mt
    )
    |> all()
  end

  def activate_profile(id, profile_name)
      when is_integer(id) and is_binary(profile_name) do
    mt = from(mt in Mixtank, where: mt.id == ^id) |> one()

    if mt != nil,
      do: Profile.activate(mt, profile_name),
      else: Logger.warn(fn -> "mixtank [#{id}] does not exist, can't activate profile" end)
  end

  def active_profile(name, :name) do
    active_profile(name)
    |> Map.get(:profiles)
    |> hd()
    |> Map.get(:name)
  end

  def active_profile(id) do
    from(
      mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      where: p.active == true,
      where: mt.id == ^id,
      select: mt,
      preload: [state: s, profiles: p]
    )
    |> one()
  end

  def active_profile_name(id) when is_integer(id) do
    mt = get_by(id: id)
    state = mt.state.state

    if state === "stopped" do
      "none"
    else
      profile = for p <- mt.profiles, p.active == true, do: p.name

      if Enum.empty?(profile), do: "none", else: hd(profile)
    end
  end

  def as_map(%Mixtank{} = mt) do
    keys = [
      :id,
      :name,
      :comment,
      :enable,
      :sensor,
      :ref_sensor,
      :pump,
      :air,
      :heater,
      :fill,
      :replenish
    ]

    mt |> Map.take(keys) |> Map.put_new(:state, State.as_map(mt.state))
    |> Map.put_new(:profiles, Profile.as_map(mt.profiles))
  end

  def available_profiles(name) when is_binary(name) do
    from(
      mt in Mixtank,
      join: p in assoc(mt, :profiles),
      where: mt.name == ^name,
      select: p.name
    )
    |> all()
  end

  def delete_all(:dangerous) do
    from(mt in Mixtank, where: mt.id >= 0)
    |> Repo.delete_all()
  end

  def disable(%Mixtank{name: name}), do: disable(name)

  def disable(name) when is_binary(name) do
    from(
      mt in Mixtank,
      where: mt.name == ^name,
      update: [set: [enable: false]]
    )
    |> update_all([])
  end

  def disable(opts) when is_list(opts) do
    opts = Keyword.put(opts, :enable, false)
    set_enable(opts)
  end

  def enable(opts) when is_list(opts) do
    opts = Keyword.put(opts, :enable, true)
    set_enable(opts)
  end

  def enable(name) when is_binary(name) do
    from(
      mt in Mixtank,
      where: mt.name == ^name,
      update: [set: [enable: true]]
    )
    |> update_all([])
  end

  def get(name) do
    from(
      mt in Mixtank,
      join: p in assoc(mt, :profiles),
      join: s in assoc(mt, :state),
      where: mt.name == ^name,
      select: mt,
      preload: [state: s, profiles: p]
    )
    |> one()
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :name, :sensor, :ref_sensor])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      mt = from(m in Mixtank, where: ^filter, preload: [:profiles, :state]) |> one()

      if is_nil(mt) or Enum.empty?(select), do: mt, else: Map.take(mt, select)
    end
  end

  def set_enable(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :name, :sensor, :ref_sensor])
    # default to false if not specified
    enable = Keyword.get(opts, :enable, false)

    {count, nil} =
      from(
        mt in Mixtank,
        where: ^filter,
        update: [set: [enable: ^enable]]
      )
      |> update_all([])

    if count === 1, do: :ok, else: :error
  end
end
