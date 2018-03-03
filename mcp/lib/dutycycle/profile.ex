defmodule Dutycycle.Profile do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Repo, only: [one: 1, update_all: 2]
  import Ecto.Query, only: [from: 2]

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

  def as_map(list) when is_list(list) do
    for dcp <- list, do: as_map(dcp)
  end

  def as_map(%Dutycycle.Profile{} = dcp) do
    keys = [
      :id,
      :name,
      :active,
      :run_ms,
      :idle_ms
    ]

    Map.take(dcp, keys)
  end

  def change(nil, _, _), do: %Dutycycle.Profile{}

  def change(%Dutycycle{} = dc, profile, opts)
      when is_binary(profile) and is_map(opts) do
    {rows_updated, _} =
      from(
        dp in Dutycycle.Profile,
        where: dp.dutycycle_id == ^dc.id,
        where: dp.name == ^profile,
        update: [set: [run_ms: ^opts.run_ms, idle_ms: ^opts.idle_ms]]
      )
      |> update_all([])

    rows_updated > 0 &&
      Logger.info(fn -> "dutycycle [#{dc.name}] " <> "profile [#{profile}] updated" end)

    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.name == ^profile
    )
    |> one
  end
end
