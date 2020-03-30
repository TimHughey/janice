defmodule Janitor.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  use Config.Helper

  def init(args) do
    log?(:init_args, true) &&
      Logger.info(["init() args: ", inspect(args, pretty: true)])

    # for Janitor, pass the same args to the workers

    to_start = workers(args)

    log?(:init, true) &&
      Logger.info(["starting workers ", inspect(to_start, pretty: true)])

    to_start
    |> Supervisor.init(strategy: :one_for_one, name: __MODULE__)
  end

  # supervisors are always autostarted
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  defp workers(args), do: [{Janitor, args}]
end
