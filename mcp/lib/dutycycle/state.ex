defmodule Dutycycle.State do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

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

end
