defmodule Mcp.Chamber.AutoPopulate do
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
      Foo Foo Foundation
    """

  import Ecto.Query, only: [from: 2]
  alias Mcp.{Repo, Chamber}

  defp default_chambers do
    [%Chamber{name: "test chamber", description: "-- FOR TESTING ONLY --",
       enable: false,
       temp_sensor_pri: "ts_shroom1", temp_sensor_sec: "ts_curetank",
       temp_setpt: 85, heat_sw: "buzzer", heat_control_ms: 20_000,
       relh_sensor: "rh_simulate", relh_sw: "buzzer", relh_control_ms: 20_000,
       air_stir_sw: "buzzer", air_stir_temp_diff: 5,
       fresh_air_sw: "buzzer", fresh_air_freq_ms: 900_000,
       fresh_air_dur_ms: 600_000},
     %Chamber{name: "main grow", description: "production",
        enable: false,
        temp_sensor_pri: "i2c_am2315", temp_sensor_sec: "ts_shroom1",
        temp_setpt: 85, heat_sw: "shroom1_heat", heat_control_ms: 20_000,
        relh_sensor: "i2c_am2315", relh_sw: "shroom1_mist",
        relh_control_ms: 20_000,
        air_stir_sw: "shroom1_air", air_stir_temp_diff: 5,
        fresh_air_sw: "shroom1_fresh_air", fresh_air_freq_ms: 900_000,
        fresh_air_dur_ms: 600_000}]
  end

  def populate(:false), do: []
  def populate(:true) do
    default_names = Enum.into(default_chambers(), [], fn(c) -> c.name end)

    query = from c in Chamber, select: c.name
    existing_names  = Repo.all(query)

    to_add = default_names -- existing_names

    add_chambers(to_add)
  end

  defp add_chambers([]), do: []
  defp add_chambers(c) when is_list(c) do
    [add_chambers(hd(c)) | add_chambers(tl(c))]
  end

  defp add_chambers(name) when is_binary(name) do
    c = Enum.find(default_chambers(), fn(c) -> c.name == name end)
    Repo.insert(c)
  end
end
