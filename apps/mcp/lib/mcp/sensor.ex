defmodule Mcp.Sensor do

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
  GenServer implementation of a Sensor capable of:
    - reading values
    - getting list of sensors
  """
  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema
  alias Ecto.Changeset

  alias Mcp.{Repo, Owfs, Sensor, Reading}

  schema "sensors" do
    field :name
    field :reading
    field :description
    field :value, :float, default: 0.0
    field :read_at, Timex.Ecto.DateTime

    timestamps usec: true
  end

  def value(n, r) when is_binary(n) and is_binary(r) do
     s = Repo.get_by(Sensor, [name: n, reading: r])

     current_reading?(s, :simple)
  end

  @doc ~S"""
   Get sensor value by name and reading

  ## Examples

    iex> Mcp.Sensor.get_by("name", "reading")
    {"name", "reading", float}

  """
  def get_by(name, reading) do
    sensor = Repo.get_by(Mcp.Sensor, [name: name, reading: reading])

    case sensor do
      :nil -> {:error, {name, reading, :nil, Timex.now()}}
      s -> current_reading?(s)
    end
  end

  defp current_reading?(:nil, :simple), do: :nil
  defp current_reading?(%Sensor{} = s, :simple) do
    case current_reading?(s) do
      {:ok, {_, _, val, _}} -> val
      {:stale, {_, _, _, _}} -> :nil
    end
  end

  defp current_reading?(%Sensor{} = s) do
    #ttl_secs = Owfs.volatile_timeout()
    ttl_secs = 60

    fresh_at = Timex.now() |> Timex.shift(seconds: ttl_secs * -1)

    rval = {s.name, s.reading, s.value, s.updated_at}
    case Timex.before?(s.read_at, fresh_at) do
      :true  -> {:stale, rval}
      :false -> {:ok, rval}
    end
  end

  def add(%Sensor{} = s) do
    s = %Sensor{s | read_at: Timex.now()}

    Repo.insert(s)
  end

  defp load_or_new(%Sensor{} = s) do
    by_opts = [name: s.name, reading: s.reading]
    loaded = Repo.get_by(Sensor, by_opts)
    load_or_new(loaded, s)
  end
  defp load_or_new(%Sensor{} = loaded, %Sensor{} = _new), do: loaded
  defp load_or_new(:nil, %Sensor{} = new), do: new

  defp change_and_persist(%Sensor{} = s, %Reading{} = r) do
    map = %{value: Reading.val(r), read_at: Reading.read_at(r)}
    s |> Changeset.change(map) |> Repo.insert_or_update()
  end

  defp check_persist({:ok, %Sensor{} = s}), do: {:ok, {s.name, s.reading}}
  defp check_persist({:error, %Changeset{} = cs}) do
    name = cs.data.name
    reading = cs.data.reading
    Logger.warn("Sensor persist for #{name} #{reading} failed")

    {:error, {name, reading}}
  end

  def persist(%Reading{} = r) do
    Reading.if_valid_execute(r, &persist/2)
  end

  def persist(%Reading{} = r, :true) do
    %Sensor{name: Reading.name(r), reading: Reading.kind(r)} |>
      load_or_new() |> change_and_persist(r) |>
      check_persist()
  end
  def persist(%Reading{} = r, :false) do
    str = "#{Reading.name(r)} #{Reading.kind(r)}"
    Logger.warn("Sensor: val error, will not #{str}")
  end

  def auto_populate do
    full_list = Owfs.sensor_and_reading_list()

    for f <- full_list do
      sensor = load %Sensor{name: f.name, reading: f.reading}

      persist_with_reading sensor, Owfs.read_sensor(sensor.name, sensor.reading)
    end |> Enum.count()
  end

  defp load(%Sensor{name: :nil}), do: :nil
  defp load(%Sensor{} = sensor) do
    case Repo.get_by Sensor, %{name: sensor.name, reading: sensor.reading} do
      :nil  -> sensor
      found -> found
    end
  end

  defp persist_with_reading(%Sensor{name: :nil}, _reading), do: :nil
  defp persist_with_reading(%Sensor{} = sensor, reading) when is_map(reading) do
    sensor |>
      Changeset.change(%{value: reading.val, read_at: reading.read_at}) |>
      Changeset.unique_constraint(:name, name: :sensors_name_reading_index) |>
      Repo.insert_or_update()
  end
end
