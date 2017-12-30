defmodule SwitchState do
@moduledoc """
  The SwitchState module provides the individual pio states for a Switch
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]
import Repo, only: [all: 2, update!: 1, one: 1]

schema "switch_state" do
  field :name, :string
  field :description, :string, default: "new switch"
  field :pio, :integer, default: 0
  field :state, :boolean, default: nil
  field :ttl_ms, :integer
  belongs_to :switch, Switch

  timestamps usec: true
end

def all(:names) do
  from(ss in SwitchState, select: ss.name) |> all(timeout: 100)
end

def all(:everything) do
  from(ss in SwitchState,
        join: sw in assoc(ss, :switch),
        order_by: [ss.name],
        preload: [switch: sw]) |> all(timeout: 100)
end

def as_list_of_maps(list) when is_list(list) do
  for ss <- list do
    %{pio: ss.pio, state: ss.state}
  end
end

def get_by_name(name) when is_binary(name) do
  from(ss in SwitchState, where: ss.name == ^name) |> one()
end

def state(name) when is_binary(name) do
  case get_by_name(name) do
    nil -> Logger.warn fn -> "#{name} not found while RETRIEVING state" end
           nil
    ss  -> ss.state
  end
end

def state(name, position)
when is_binary(name) and is_boolean(position) do
  case get_by_name(name) do
    nil -> Logger.warn fn -> "#{name} not found while SETTING state" end
           nil
    ss  -> new_ss = change(ss, state: position) |> update!()
           SwitchCmd.record_cmd(name, new_ss)
           # Switch.states_updated(name, ss.switch_id)
           position
  end
end

def state(name, position, :lazy)
when is_binary(name) and is_boolean(position) do
  if state(name) != position, do: state(name, position), else: position
end

end
