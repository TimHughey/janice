defmodule Mcp.SwitchState do
@moduledoc """
  The SwitchState module provides the individual pio states for a Switch
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

alias Mcp.SwitchState

schema "switch_state" do
  field :pio, :integer, default: 0
  field :state, :boolean, default: nil
  field :ttl_ms, :integer
  belongs_to :switch, Mcp.Switch

  timestamps usec: true
end

def as_list_of_maps([%SwitchState{} = ss | _rest] = list) do
  [as_map(ss)] ++ as_list_of_maps(tl(list))
end

def as_list_of_maps([]), do: []

def as_map(%SwitchState{pio: pio, state: state}), do: %{pio: pio, state: state}

end
