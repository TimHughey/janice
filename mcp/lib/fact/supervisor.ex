defmodule Fact.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  alias Fact.Influx

  def init(_args) do
    Logger.info(fn -> "init()" end)

    # List all child processes to be supervised
    children = [
      Influx.child_spec()
    ]

    opts = [strategy: :one_for_all, name: Fact.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
end
