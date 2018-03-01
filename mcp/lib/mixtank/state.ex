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
    Dutycycle.get(name) |> set_stopped()
  end

  def set_stopped(nil), do: {:not_found}

  def set_stopped(%Mixtank{} = mt) do
    Dutycycle.Control.disable_cycle(mt.pump)
    Dutycycle.Control.disable_cycle(mt.air)
    Dutycycle.Control.disable_cycle(mt.heater)
    Dutycycle.Control.disable_cycle(mt.fill)
    Dutycycle.Control.disable_cycle(mt.replenish)

    now = Timex.now()

    from(
      s in State,
      where: s.mixtank_id == ^mt.id,
      update: [set: [state: "stopped", started_at: nil, state_at: ^now]]
    )
    |> update_all([])
  end
end
