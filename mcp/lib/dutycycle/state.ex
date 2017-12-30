defmodule Dutycycle.State do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Repo, only: [update_all: 2]
  import Ecto.Query, only: [from: 2]

  schema "dutycycle_state" do
    field :state
    field :dev_state, :boolean
    field :run_at, Timex.Ecto.DateTime
    field :run_end_at, Timex.Ecto.DateTime
    field :idle_at, Timex.Ecto.DateTime
    field :idle_end_at, Timex.Ecto.DateTime
    field :started_at, Timex.Ecto.DateTime
    field :state_at, Timex.Ecto.DateTime
    belongs_to :dutycycle, Dutycycle

    timestamps usec: true
  end

  def set_idling(%Dutycycle{} = dc) do
    now = Timex.now()
    profile = dc.profiles |> hd()
    idle_end_at = Timex.to_datetime(now, "UTC") |>
                Timex.shift(milliseconds: profile.idle_ms)

    from(s in Dutycycle.State,
      where: s.dutycycle_id == ^dc.id,
      update: [set:
        [state: "idling", dev_state: false,
         idle_at: ^now, idle_end_at: ^idle_end_at,
         run_at: nil, run_end_at: nil,
         state_at: ^now]]) |> update_all([])
  end

  def set_running(%Dutycycle{} = dc) do
    now = Timex.now()
    profile = dc.profiles |> hd()
    run_end_at = Timex.to_datetime(now, "UTC") |>
                Timex.shift(milliseconds: profile.run_ms)

    from(s in Dutycycle.State,
      where: s.dutycycle_id == ^dc.id,
      update: [set:
        [state: "running", dev_state: true,
         idle_at: nil, idle_end_at: nil,
         run_at: ^now, run_end_at: ^run_end_at,
         state_at: ^now]]) |> update_all([])
  end

  def set_started(%Dutycycle{} = dc) do
    now = Timex.now()

    from(s in Dutycycle.State,
      where: s.dutycycle_id == ^dc.id,
      update: [set:
        [state: "started", dev_state: false,
         idle_at: nil, idle_end_at: nil,
         run_at: nil, run_end_at: nil,
         started_at: ^now,
         state_at: ^now]]) |> update_all([])
  end

  def set_stopped(name) when is_binary(name) do
    Dutycycle.active_profile(name) |> set_stopped()
  end

  def set_stopped(nil), do: {:not_found}
  def set_stopped(%Dutycycle{} = dc) do
    now = Timex.now()

    from(s in Dutycycle.State,
      where: s.dutycycle_id == ^dc.id,
      update: [set:
        [state: "stopped", dev_state: false,
         idle_at: nil, idle_end_at: nil,
         run_at: nil, run_end_at: nil,
         started_at: nil,
         state_at: ^now]]) |> update_all([])
  end



end
