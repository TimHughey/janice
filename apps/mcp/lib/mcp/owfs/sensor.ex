defmodule Mcp.Owfs.Sensor do
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

  use Timex
  require Logger

  alias Mcp.{Owfs, Owfs.Util, Reading}

  @temperature "temperature"
  #@xhires_temperature "temperature12"
  #@hires_temperature "temperature10"
  #@lores_temperature "temperature"
  @humidity "humidity"

  # External API
  def all, do: full_list() |> filter_list(Owfs.sensor_regex()) |> Enum.sort
  def available_readings(n) when is_binary(n) do
    possible = [@temperature, @humidity]
    Enum.filter(possible, fn(x) -> File.exists?(reading_path(n, x)) end) 
  end

  def reading(name) when is_binary(name) do
    for reading <- available_readings(name) do
      reading(name, reading)
    end
  end

  def reading(name, @temperature) when is_binary(name) do
    res = :timer.tc(&read_temperature/1, [name])
    Reading.create(name, @temperature, res, Owfs.ttl())
  end

  def reading(name, @humidity) when is_binary(name) do
    res = :timer.tc(&read_humidity/1,[name])
    Reading.create(name, @humidity, res, Owfs.ttl())
  end

  def reading(name, reading)
  when is_binary(name) and is_binary(reading) do
    msg = "Owfs.Sensor: #{name} unknown reading: #{reading}"
    Logger.warn(msg)
    Reading.create(name, reading, {0, {:error, 0.0}}, Owfs.ttl())
  end

  #
  # Private functions
  #

  defp full_list, do: File.ls(Util.owfs_path())
  defp filter_list({:error, _type}, _regex), do: []
  defp filter_list({:ok, raw_list}, regex) when is_list(raw_list) do
    Enum.filter(raw_list, &Regex.match?(regex, &1))
  end

  def sensor_path(name) do
    Path.join([Owfs.config(:path), name])
  end

  def reading_path(name, reading) do
    Path.join([Owfs.config(:path), name, reading])
  end

  def reading_file?(file) do
    # file in [@temperature, @hires_temperature, @lores_temperature, @humidity]
    file in [@temperature, @humidity]
  end

  defp read_temperature(name) when is_binary(name) do
    read_val(temperature_path(name))
  end

  defp temperature_path(:nil), do: :nil
  defp temperature_path(n) when is_binary(n) do
    reading_path(n, @temperature)
  end 
  #defp temperature_path(n), do: temperature_path(n, @hires_temperature)
  #defp temperature_path(name, granulatity) do
  #  case File.stat(reading_path(name, granulatity)) do
  #    {:ok, _}          -> reading_path(name, granulatity)
  #    {:error, :enoent} -> temperature_path(name, @lores_temperature)
  #    _                 -> :nil
  #  end
  #end

  defp read_humidity(name) when is_binary(name) do
    read_val(reading_path(name, @humidity))
  end

  defp read_val(:nil), do: {:error, :nil}
  defp read_val(file_path) do
    with {:ok, binary} <- File.read(file_path),
         {reading, ""} <- Float.parse(binary),
         do: {:ok, reading}
  end

end
