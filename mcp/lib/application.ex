defmodule Mcp.Application do
  @moduledoc false

  use Application
  require Logger
  import Application, only: [get_env: 3, put_env: 3]
  import Keyword, only: [has_key?: 2]

  def start(_type, args) do
    Logger.info(fn -> "start() args: #{inspect(args)}" end)

    build_env = Keyword.get(args, :build_env, "dev")

    put_env(:mcp, :build_env, build_env)

    # List all child processes to be supervised
    children = children_by_env(build_env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :rest_for_one,
      name: Mcp.Supervisor,
      max_restarts: 100,
      max_seconds: 5
    ]

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

    base = [{Repo, []}]

    protocols =
      case build_env do
        "standby" ->
          []

        _othets ->
          [{Fact.Supervisor, initial}, {Mqtt.Supervisor, initial}]
      end

    apps =
      case build_env do
        "dev" ->
          [{Janitor, %{autostart: true}}, {Thermostat.Supervisor, initial}]

        "test" ->
          [
            {Janitor, initial},
            {Dutycycle.Supervisor, initial},
            {Thermostat.Supervisor, initial}
          ]

        "prod" ->
          [
            {Janitor, initial},
            {Dutycycle.Supervisor, initial},
            {Thermostat.Supervisor, initial}
          ]

        "standby" ->
          []

        _others ->
          []
      end

    additional =
      case build_env do
        "standby" -> []
        _others -> [{Janice.Scheduler, []}]
      end

    base ++ protocols ++ apps ++ additional
  end

  defp initial_args(build_env) when is_binary(build_env) do
    case build_env do
      "dev" ->
        %{autostart: false}

      "test" ->
        %{autostart: true}

      "prod" ->
        %{autostart: true}

      "standby" ->
        %{autostart: false}

      _unmatched ->
        %{autostart: false}
    end
  end
end
