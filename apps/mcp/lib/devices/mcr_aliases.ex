defmodule Mcp.McrAlias do
@moduledoc false

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema
import Mcp.Repo, only: [get_by: 2, insert_or_update: 1]
import Ecto.Changeset, only: [change: 2]
import Ecto.Adapters.SQL, only: [query!: 2]

alias Mcp.McrAlias
alias Mcp.Repo

schema "mcr_aliases" do
  field :device
  field :friendly_name
  field :description
  field :dt_last_used, Timex.Ecto.DateTime

  timestamps usec: true
end

@doc ~S"""
Retrieve a friendly name for a device id
If the device doesn't exist a new friendly_name will be created

## Examples:
  iex> Mcp.McrAlias.friendly_name("i2c/f8f005f73b53.01.sht31")
  "relhum"

  iex> Mcp.McrAlias.friendly_name("ds/nodev") |> String.starts_with?("new")
  true
"""
def friendly_name(device) when is_binary(device) do
  case get_by(McrAlias, [device: device]) do
    nil -> %McrAlias{device: device,
                     friendly_name: new_friendly_name(),
                     description: "auto created for unknown device"}
           |> add |> Map.get(:friendly_name)
    d -> d.friendly_name
  end
end

@doc ~S"""
Retrieve a device id for a friendly name

## Examples:
  iex> Mcp.McrAlias.device("relhum")
  "i2c/f8f005f73b53.01.sht31"

  iex> Mcp.McrAlias.device("unknown")
  nil

"""
def device(friendly_name) when is_binary(friendly_name) do
  case get_by(McrAlias, [friendly_name: friendly_name]) do
    nil -> nil
    d -> d.device
  end
end

@doc ~S"""
Retrieve the last time a friendly name was used

## Examples:
  iex> Mcp.McrAlias.last_used("relhum") |> Timex.is_valid?
  true

  iex> Mcp.McrAlias.last_used("bad test dev")
  nil
"""
def last_used(friendly_name) when is_binary(friendly_name) do
  case get_by(McrAlias, [friendly_name: friendly_name]) do
    nil -> nil
    d -> d.dt_last_used
  end
end

@doc ~S"""
Add a new McrAlias

## Examples:
  iex> d = %Mcp.McrAlias{friendly_name: "relhum",
  ...>                   device: "i2c/f8f005f73b53.01.sht31"}
  ...> %{friendly_name: friendly_name} = Mcp.McrAlias.add(d)
  ...> friendly_name
  "relhum"
"""
def add(%McrAlias{} = d) do
  to_add =
    case get_by(McrAlias, friendly_name: d.friendly_name) do
      nil -> d
      friendly_name -> friendly_name
    end

  update = [dt_last_used: Timex.now()]

  {:ok, added} = to_add |> change(update) |> insert_or_update
  added
end

@doc ~S"""
Get a new friendly name
 - useful for creating a new alias for a device id not previously knowns

## Examples:
  iex> Mcp.McrAlias.new_friendly_name() |> String.starts_with?("new")
  true
"""
def new_friendly_name do
  query = ~S/ select nextval('mcr_alias_seq') /

  %{rows: [[next_num]]} = query!(Repo, query)
  num_str = next_num |> Integer.to_string() |> String.pad_leading(6, "0")
  "new_#{num_str}"
end

end
