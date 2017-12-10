defmodule Mcp.DevAlias do
@moduledoc false

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema
import Ecto.Adapters.SQL, only: [query!: 2]
import Ecto.Changeset, only: [change: 2]
import Ecto.Query, only: [from: 2]
import Mcp.Repo, only: [all: 2, get_by: 2, insert_or_update: 1,
                        one: 1, update!: 1]

alias Mcp.DevAlias
alias Mcp.Repo

schema "dev_alias" do
  field :device
  field :friendly_name
  field :description
  field :last_seen_at, Timex.Ecto.DateTime

  timestamps usec: true
end

def all do
  from(dev in DevAlias, order_by: :friendly_name) |>
    all(timeout: 100)
end

def all(:friendly_names) do
  from(dev in DevAlias, order_by: :friendly_name, select: dev.friendly_name) |>
    all(timeout: 100)
end

@doc ~S"""
Retrieve a friendly name for a device id
If the device doesn't exist a new friendly_name will be created

## Examples:
  iex> Mcp.DevAlias.friendly_name("i2c/F8F005F73FFF.01.sht31")
  "relhum"

  iex> Mcp.DevAlias.friendly_name("ds/nodev") |> String.starts_with?("new")
  true
"""
def friendly_name(device) when is_binary(device) do
  case get_by(DevAlias, [device: device]) do
    nil -> %DevAlias{device: device,
                     friendly_name: new_friendly_name(),
                     description: "auto created for unknown device"}
           |> add |> Map.get(:friendly_name)
    d -> d.friendly_name
  end
end

def friendly_name(nil), do: nil

@doc ~S"""
Retrieve a device id for a friendly name

## Examples:
  iex> Mcp.DevAlias.device("relhum")
  "i2c/F8F005F73FFF.01.sht31"

  iex> Mcp.DevAlias.device("unknown")
  nil

"""
def device(friendly_name) when is_binary(friendly_name) do
  case get_by(DevAlias, [friendly_name: friendly_name]) do
    nil -> nil
    d -> d.device
  end
end

def get_by_friendly_name(friendly_name) when is_binary(friendly_name) do
  case get_by(DevAlias, [friendly_name: friendly_name]) do
    nil -> nil
    d -> d
  end
end

@doc ~S"""
Mark an alias as just seen
"""
def just_seen(id)
when is_binary(id) do
  query =
    from(dev in DevAlias,
      where: (dev.device == ^id) or (dev.friendly_name == ^id))

  one(query) |> just_seen()
end

def just_seen(%DevAlias{} = dev) do
  change(dev, last_seen_at: Timex.now()) |> update!()
end

def just_seen([]), do: []

def just_seen(ids)
when is_list(ids) do
  [just_seen(hd(ids))] ++ just_seen(tl(ids))
end

def just_seen(nil), do: nil

@doc ~S"""
Retrieve the last time a friendly name was used

## Examples:
  iex> Mcp.DevAlias.last_seen("relhum") |> Timex.is_valid?
  true

  iex> Mcp.DevAlias.last_seen("bad test dev")
  nil
"""
def last_seen(friendly_name) when is_binary(friendly_name) do
  case get_by(DevAlias, [friendly_name: friendly_name]) do
    nil -> nil
    d -> d.last_seen_at
  end
end

def add([]), do: []
def add([%DevAlias{} = da | rest]) do
  [add(da)] ++ add(rest)
end

@doc ~S"""
Add a new DevAlias

## Examples:
  iex> d = %Mcp.DevAlias{friendly_name: "relhum",
  ...>                   device: "i2c/f8f005f73fff.01.sht31"}
  ...> %{friendly_name: friendly_name} = Mcp.DevAlias.add(d)
  ...> friendly_name
  "relhum"
"""
def add(%DevAlias{} = d) do
  to_add =
    case get_by(DevAlias, friendly_name: d.friendly_name) do
      nil -> d
      friendly_name -> friendly_name
    end

  update = [last_seen_at: Timex.now()]

  {:ok, added} = to_add |> change(update) |> insert_or_update
  added
end

@doc ~S"""
Get a new friendly name
 - useful for creating a new alias for a device id not previously knowns

## Examples:
  iex> Mcp.DevAlias.new_friendly_name() |> String.starts_with?("new")
  true
"""
def new_friendly_name do
  query = ~S/ select nextval('seq_dev_alias') /

  %{rows: [[next_num]]} = query!(Repo, query)
  num_str = next_num |> Integer.to_string() |> String.pad_leading(6, "0")
  "z#{num_str}"
end

def dump do
  a = from(dev in DevAlias, order_by: :device) |>
    all(timeout: 100)

 {:ok, pid} = File.open("/tmp/dev_alias.ex", [:write, :utf8])

 strings = Enum.map(a, &as_string/1)

 output = "  [\n" <> Enum.join(strings, ",\n") <> "\n  ]"

 IO.write(pid, output)

 File.close(pid)
end

defp as_string(%DevAlias{} = da) do
  ~s(   %DevAlias{friendly_name: "#{da.friendly_name}",) <> "\n" <>
  ~s(     device: "#{da.device}",) <> "\n" <>
  ~s(     description: "#{da.description}"})
end

end
