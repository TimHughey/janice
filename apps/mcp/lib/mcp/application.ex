defmodule Mcp.Application do
# See https://hexdocs.pm/elixir/Application.html
# for more information on OTP Applications
@moduledoc false

use Application
import Application, only: [fetch_env: 2, get_env: 3]
import Keyword, only: [has_key?: 2]

def start(_type, _args) do

  autostart =
  case fetch_env(:mcp, :build_env) do
    {:ok, "test"}  -> false
    _anything_else -> true
  end

  initial_state = %{autostart: autostart}

  # List all child processes to be supervised
  children = [
    Mcp.Repo,
    {Mcp.SoakTest, initial_state},
    {Mcp.Janitor, initial_state},
    {Mcp.Dutycycle, initial_state},
    {Mcp.Mixtank, initial_state},
    {Mcp.Chamber, initial_state}
  ]

  opts = [strategy: :one_for_one, name: Mcp.Supervisor]

  # only start the Supervisor if the database password is set
  if get_env(:mcp, Mcp.Repo, []) |> has_key?(:password) do
    Supervisor.start_link(children, opts)
  else
    {:error, :no_db_password}
  end

end

end
