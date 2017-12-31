defmodule Dutycycle.Profile do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Repo, only: [update_all: 2]
  import Ecto.Query, only: [from: 2]

  schema "dutycycle_profile" do
    field :name
    field :active, :boolean, default: false
    field :run_ms, :integer
    field :idle_ms, :integer
    belongs_to :dutycycle, Dutycycle

    timestamps usec: true
  end

  def activate(%Dutycycle{} = dc, name) when is_binary(name) do
    from(dp in Dutycycle.Profile,
          where: dp.dutycycle_id == ^dc.id,
          where: dp.active == true,
          update: [set: [active: false]]) |> update_all([])

    from(dp in Dutycycle.Profile,
          where: dp.dutycycle_id == ^dc.id,
          where: dp.name == ^name,
          update: [set: [active: true]]) |> update_all([])
  end

end
