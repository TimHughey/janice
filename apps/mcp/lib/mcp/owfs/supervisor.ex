defmodule Mcp.Owfs.Supervisor do

  @moduledoc :false

  use Supervisor
  require Logger

  def start_link(arg) do
    Supervisor.start_link(Mcp.Owfs.Supervisor, arg, name: Mcp.Owfs.Supervisor)
  end

  def init(_arg) do
    opts = [strategy: :one_for_one]

    children =
      [worker(Mcp.Owfs, [%{}]),
       supervisor(Task.Supervisor, [[name: Mcp.Owfs.Task.Supervisor]])]

    supervise(children, opts)
  end
end
