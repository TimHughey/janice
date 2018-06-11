defmodule Mcp.Application do
  @moduledoc false

  use Application
  require Logger
  import Application, only: [get_env: 3, put_env: 3]
  import Keyword, only: [has_key?: 2]

  def start(_type, args) do
    Logger.info(fn -> "start() args: #{inspect(args)}" end)

    build_env = Keyword.get(args, :build_env, "dev")
    sha_head = Keyword.get(args, :sha_head, "0000000")
    sha_mcr_stable = Keyword.get(args, :sha_mcr_stable, "0000000")

    put_env(:mcp, :build_env, build_env)
    put_env(:mcp, :sha_head, sha_head)
    put_env(:mcp, :sha_mcr_stable, sha_mcr_stable)

    # List all child processes to be supervised
    children = children_by_env(build_env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Mcp.Supervisor, max_restarts: 100, max_seconds: 5]

    # only start the Supervisor if the database password is set
    if get_env(:mcp, Repo, []) |> has_key?(:password) do
      Supervisor.start_link(children, opts)
    else
      {:error, :no_db_password}
    end
  end

  # Private Functions
  defp children_by_env(build_env) when is_binary(build_env) do
    initial = initial_args(build_env)

    first = [{Repo, []}, {Fact.Supervisor, initial}, {Mqtt.Supervisor, initial}]

    specific =
      case build_env do
        "dev" ->
          [{Janitor, initial}, {Dutycycle.Supervisor, initial}, {Thermostat.Supervisor, initial}]

        "test" ->
          [{Janitor, initial}, {Dutycycle.Supervisor, initial}, {Thermostat.Supervisor, initial}]

        "prod" ->
          [{Janitor, initial}, {Dutycycle.Supervisor, initial}, {Thermostat.Supervisor, initial}]
      end

    last = [{Web.Supervisor, initial}]

    first ++ specific ++ last
  end

  defp initial_args(build_env) when is_binary(build_env) do
    case build_env do
      "dev" ->
        %{autostart: true}

      "test" ->
        %{autostart: true}

      "prod" ->
        %{autostart: true}
    end
  end
end
