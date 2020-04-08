defmodule Fact.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  alias Fact.Influx

  def init(args) do
    Logger.debug(["init() args: ", inspect(args, pretty: true)])

    # List all child processes to be supervised
    children = [
      Influx.child_spec()
    ]

    opts = [strategy: :rest_for_one, name: Fact.Supervisor]
    Supervisor.init(children, opts)
  end

  def start_link(args) when is_list(args) do
    Supervisor.start_link(__MODULE__, Enum.into(args, %{}), name: __MODULE__)
  end
end
