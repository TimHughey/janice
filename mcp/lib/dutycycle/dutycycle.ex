defmodule Dutycycle do

#    Master Control Program for Wiss Landing
#    Copyright (C) 2016  Tim Hughey (thughey)

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>

  @moduledoc """
  GenServer implementation of Dutycycle controller capable of:
    - controlling a single device
    - to maintain temperature in alignment with reference
  """

  require Logger
  use GenServer
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  use Timex

  import Mcp.Repo, only: [all: 1, one: 1, insert_or_update!: 1]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  @vsn 3

  schema "dutycycle" do
    field :name
    field :description
    field :enable, :boolean
    field :device
    has_one :state, Dutycycle.State
    has_many :modes, Dutycycle.Mode

    timestamps usec: true
  end

  def add([]), do: []
  def add([%Dutycycle{} = dc | rest]) do
    [add(dc)] ++ add(rest)
  end

  def add(%Dutycycle{name: name} = dc) do
    q = from(d in Dutycycle, where: d.name == ^name, select: {d})

    case one(q) do
      nil   -> change(dc, []) |> insert_or_update!()
      found -> Logger.warn ~s/add() [#{dc.name}] already exists/
               found
    end
  end

  def all do
    from(d in Dutycycle,
      join: m in assoc(d, :modes),
      join: s in assoc(d, :state),
      preload: [modes: m, state: s],
      select: {d}) |> all()
  end

  def active_mode(name) do
    from(d in Dutycycle,
      join: m in assoc(d, :modes),
      join: s in assoc(d, :state),
      where: m.active == true,
      where: d.name == ^name,
      select: {d},
      preload: [state: s, modes: m]) |> one()

  end


end
