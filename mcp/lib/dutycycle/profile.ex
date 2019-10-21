defmodule Dutycycle.Profile do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Repo, only: [one: 1, update_all: 2]
  import Ecto.Query, only: [from: 2]

  alias Dutycycle.Profile

  schema "dutycycle_profile" do
    field(:name)
    field(:active, :boolean, default: false)
    field(:run_ms, :integer)
    field(:idle_ms, :integer)
    belongs_to(:dutycycle, Dutycycle)

    timestamps(usec: true)
  end

  def activate(%Dutycycle{} = dc, name) when is_binary(name) do
    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.active == true,
      update: [set: [active: false]]
    )
    |> update_all([])

    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.name == ^name,
      update: [set: [active: true]]
    )
    |> update_all([])
  end

  def active(nil), do: nil

  def active(%Dutycycle{} = d), do: active(d.profiles)

  def active([%Profile{} | _rest] = profiles) do
    active = for p <- profiles, p.active, do: p

    if Enum.empty?(active), do: :none, else: hd(active)
  end

  def add(%Dutycycle{} = d, %Profile{} = p) do
    Ecto.build_assoc(d, :profiles, p) |> Repo.insert!()
  end

  def as_map(list) when is_list(list) do
    for dcp <- list, do: as_map(dcp)
  end

  def as_map(%Dutycycle.Profile{} = dcp) do
    keys = [
      :id,
      :name,
      :active,
      :run_ms,
      :idle_ms,
      :updated_at
    ]

    Map.take(dcp, keys)
  end

  def change(nil, _, _), do: %Dutycycle.Profile{}

  def change(%Dutycycle{} = dc, profile, opts)
      when is_binary(profile) and is_list(opts) do
    set = Keyword.take(opts, [:run_ms, :idle_ms])
    log = Keyword.get(opts, :log, false)

    {rows_updated, _} =
      from(
        dp in Dutycycle.Profile,
        where: dp.dutycycle_id == ^dc.id,
        where: dp.name == ^profile,
        update: [set: ^set]
      )
      |> update_all([])

    rows_updated > 0 && log &&
      Logger.info(fn ->
        "dutycycle [#{dc.name}] profile [#{profile}] updated"
      end)

    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.name == ^profile
    )
    |> one
  end

  def phase_ms(%Dutycycle.Profile{idle_ms: ms}, :idle), do: ms
  def phase_ms(%Dutycycle.Profile{run_ms: ms}, :run), do: ms
end
