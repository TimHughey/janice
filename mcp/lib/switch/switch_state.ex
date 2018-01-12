defmodule SwitchState do
@moduledoc """
  The SwitchState module provides the individual pio states for a Switch
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

#import Ecto.Changeset, only: [cast: 2, change: 2]
import Ecto.Changeset
import Ecto.Query, only: [from: 2]
import Repo, only: [all: 2, delete_all: 1, get: 2, update!: 1,
                    update: 1, one: 1]

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

def changeset(ss, params \\ %{}) do
  ss
  |> cast(params, [:name, :description])
  |> validate_required([:name])
  |> validate_format(:name, ~r/^[\w]+[\w ]{1,}[\w]$/)
  |> unique_constraint(:name)
end

def change_name(id, to_be, comment \\ "")
def change_name(id, tobe, comment) when is_integer(id) do
  ss = get(SwitchState, id)

  if not is_nil(ss) do
    ss
    |> changeset(%{name: tobe, description: comment})
    |> update()
  else
    Logger.info fn -> "change name failed" end
    {:error, :not_found}
  end
end

def change_name(asis, tobe, comment)
when is_binary(asis) and is_binary(tobe) do

  ss = get_by_name(asis)

  if not is_nil(ss) do
    ss
    |> changeset(%{name: tobe, description: comment})
    |> update()
  else
    {:error, :not_found}
  end
end

def delete(id) when is_integer(id) do
  from(ss in SwitchState, where: ss.id == ^id) |> delete_all()
end

def delete(name) when is_binary(name) do
  from(ss in SwitchState, where: ss.name == ^name) |> delete_all()
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
    ss  -> state(ss, position)
  end
end

def state(%SwitchState{name: name} = ss, position) when is_boolean(position) do
  new_ss = change(ss, state: position) |> update!()
  SwitchCmd.record_cmd(name, new_ss)
  position
end

def state(name, position, :lazy)
when is_binary(name) and is_boolean(position) do
  if state(name) != position, do: state(name, position), else: position
end

def toggle(id) when is_integer(id) do
  ss = get(SwitchState, id)

  if not is_nil(ss) do
    state(ss, (not ss.state))
  else
    {:error, :not_found}
  end
end

end
