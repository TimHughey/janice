defmodule Mcp.SwitchState do
@moduledoc """
  The SwitchState module provides the individual pio states for a Switch
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

schema "switch_state" do
  field :pio, :integer, default: 0
  field :state, :boolean, default: nil
  field :ttl_ms, :integer
  belongs_to :switch, Mcp.Switch

  timestamps usec: true
end

end
