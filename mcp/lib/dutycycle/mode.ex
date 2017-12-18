defmodule Dutycycle.Mode do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  schema "dutycycle_mode" do
    field :name
    field :active, :boolean, default: false
    field :run_ms, :integer
    field :idle_ms, :integer
    belongs_to :dutycycle, Dutycycle

    timestamps usec: true
  end

end