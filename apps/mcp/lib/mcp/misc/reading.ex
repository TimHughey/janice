defmodule Mcp.Reading do
  def license, do: """
     Master Control Program for Wiss Landing
     Copyright (C) 2016  Tim Hughey (thughey)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <http://www.gnu.org/licenses/>
     """

  @moduledoc """
    This module implements Owfs as a GenServer
  """

  require Logger

  use Timex
  alias Mcp.Reading

  defstruct name: "no_name", kind: "no_kind",
    read_at: Timex.zero(), read_us: 0, val: 0.0, ttl: 0

  @name :name
  @kind :kind
  @val :val
  @read_at :read_at
  @read_us :read_us
  @ttl :ttl

  @def_ttl 30_000   # in milliseconds

  @spec kinds() :: [String.t]
  def kinds, do: ["temperature", "humidity"]

  def create(n, k, v) when is_tuple(v) do
    create(n, k, v, @def_ttl)
  end
  def create(n, k, v) when is_number(v) do
    create(n, k, {1, {:ok, v}})
  end
  def create(name, kind, {read_us, {:ok, val}}, ttl)
  when is_binary(name) and is_binary(kind) and is_float(val) and
  is_integer(read_us) and is_integer(ttl) do
    %Reading{@name => name, @kind => kind,
      @val => val, @read_at => Timex.now(),
      @read_us => read_us, @ttl => ttl}
  end
  def create(name, kind, {read_us, {:error, _val}}, ttl)
  when is_binary(name) and is_binary(kind) and
  is_integer(read_us) and is_integer(ttl) do
    %Reading{@name => name, @kind => kind,
      @val => :error, @read_at => Timex.now(),
      @read_us => read_us, @ttl => ttl}
  end

  def invalid?(%Reading{} = r), do: not valid?(r)
  def valid?(%Reading{@val => v} = r)
  when is_number(v) do
     current?(r)
  end
  def valid?(%Reading{@name => "no_name", @kind => "no_kind"}), do: false
  def valid?(%Reading{@val => :error}), do: false
  def valid?(%Reading{}, _ttl), do: false

  def current?(%Reading{} = r) do
    ttl = r.ttl

    case Timex.diff(Timex.now(), r.read_at, :milliseconds) do
      x when x < ttl  -> :true
      x when x >= ttl -> :false
    end
  end

  def name(%Reading{@name => n}), do: n
  def kind(%Reading{@kind => k}), do: k
  def val(%Reading{@val => v}), do: v
  def read_us(%Reading{@read_us => rus}), do: rus
  def read_at(%Reading{@read_at => read_at}), do: read_at
  def read_at_ns(%Reading{@read_at => read_at}) do
    (read_at |> Timex.to_unix()) * trunc(:math.pow(10,9))
  end

  def humidity?(%Reading{@kind => "humidity"}), do: true
  def humidity?(%Reading{}), do: false

  def temperature?(%Reading{@kind => "temperature"}), do: true
  def temperature?(%Reading{}), do: false

  def if_valid_execute(%Reading{@val => v} = r, func)
  when is_number(v) and is_function(func, 2) do
    func.(r, :true)
  end 
  def if_valid_execute(%Reading{@val => :error} = r, func)
  when is_function(func, 2) do
    func.(r, :false)
  end 

end
