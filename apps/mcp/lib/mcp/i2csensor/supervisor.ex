defmodule Mcp.I2cSensor.Supervisor do
  @moduledoc :false

  use Supervisor
  require Logger

  def start_link(arg) do
    Supervisor.start_link(Mcp.I2cSensor.Supervisor, arg,
                          name: Mcp.I2cSensor.Supervisor)
  end

  def init(_arg) do
    opts = [strategy: :one_for_one]

    children =
      [supervisor(Task.Supervisor, [[name: Mcp.I2cSensor.Task.Supervisor]]),
       worker(Mcp.I2cSensor, [%{}])]

    supervise(children, opts)
  end
end
