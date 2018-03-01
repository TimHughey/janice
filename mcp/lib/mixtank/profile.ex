defmodule Mixtank.Profile do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  alias Mixtank.Profile

  import Repo, only: [update_all: 2]
  import Ecto.Query, only: [from: 2]

  schema "mixtank_profile" do
    field(:name)
    field(:active, :boolean, default: false)
    field(:pump)
    field(:air)
    field(:fill)
    field(:replenish)
    field(:temp_diff, :integer, default: 0)
    belongs_to(:mixtank, Mixtank)

    timestamps(usec: true)
  end

  def activate(%Mixtank{} = mt, name) when is_binary(name) do
    from(
      mt in Mixtank.Profile,
      where: mt.mixtank_id == ^mt.id,
      where: mt.active == true,
      update: [set: [active: false]]
    )
    |> update_all([])

    from(
      mt in Mixtank.Profile,
      where: mt.mixtank_id == ^mt.id,
      where: mt.name == ^name,
      update: [set: [active: true]]
    )
    |> update_all([])
  end

  def as_map(l) when is_list(l), do: for(p <- l, do: as_map(p))

  def as_map(%Profile{} = mtp) do
    keys = [:id, :name, :active, :pump, :air, :fill, :replenish, :temp_diff]

    Map.take(mtp, keys)
  end
end
