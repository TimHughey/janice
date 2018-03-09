defmodule Mixtank.State do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Repo, only: [update_all: 2]
  import Ecto.Query, only: [from: 2]

  alias Mixtank.State

  schema "mixtank_state" do
    field(:state)
    field(:started_at, Timex.Ecto.DateTime)
    field(:state_at, Timex.Ecto.DateTime)
    belongs_to(:mixtank, Mixtank)

    timestamps(usec: true)
  end

  def as_map(%State{} = mts) do
    keys = [:id, :state, :started_at, :state_at]

    Map.take(mts, keys)
  end

  def set_started(%Mixtank{} = mt) do
    now = Timex.now()

    from(
      s in State,
      where: s.mixtank_id == ^mt.id,
      update: [set: [state: "started", started_at: ^now, state_at: ^now]]
    )
    |> update_all([])
  end

  def set_stopped(name) when is_binary(name) do
    Mixtank.get(name) |> set_stopped()
  end

  def set_stopped(nil), do: {:not_found}

  def set_stopped(%Mixtank{} = mt) do
    Dutycycle.Server.disable(mt.pump)
    Dutycycle.Server.disable(mt.air)
    Dutycycle.Server.disable(mt.heater)
    Dutycycle.Server.disable(mt.fill)
    Dutycycle.Server.disable(mt.replenish)

    now = Timex.now()

    from(
      s in State,
      where: s.mixtank_id == ^mt.id,
      update: [set: [state: "stopped", started_at: nil, state_at: ^now]]
    )
    |> update_all([])
  end
end
