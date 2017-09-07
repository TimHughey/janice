defmodule Mcp.GenServer do

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

  @moduledoc :false

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      use GenServer

      def server_status, do: :sys.get_status(server_name())
      def get_status, do: :sys.get_status(server_name())
      def get_state, do: :sys.get_state(server_name())

      def config(key) do
        mod = config_key()
        Application.get_env(:mcp, :genservers)[mod][key]
      end

      def config_key, do: __MODULE__
#      def config_key, do: config_key(__MODULE__)
#      def config_key(mod) do
#        mod |> Atom.to_string() |>
#          String.replace_leading("Elixir.Mcp.", "") |>
#          String.replace(".", "_") |> String.to_atom()
#      end

      def server_name do
        mod = config_key()
        case Application.get_env(:mcp, :genservers)[mod][:name] do
          {:local, name} -> name
          {:global, name} -> {:global, name}
        end
      end

      def start_link(mod, args, state) when is_map(state) do
          start_helper(mod, args, state)
      end

      def should_start? do
        Application.get_env(:mcp, :autostart)
      end

      defp start_helper(mod, {:global, name}, init_state) do
        if Node.self() == config(:run_node) do
          result = GenServer.start_link(mod, init_state, name: name)

          case result do
            {:ok, pid} -> :global.register_name(name, pid)
            x -> x
          end

          result
        else
          :ignore
        end
      end

      defp start_helper(mod, {:local, name}, init_state) do
        GenServer.start_link(mod, init_state, name: name)
      end
    end
  end
end
