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
  defp children_by_env(build_env) when is_binary(build_env),
    do:
      [{Repo, []}] ++
        protocols(build_env) ++
        apps(build_env) ++ support(build_env) ++ support(build_env)

  defp apps(build_env) do
    case build_env do
      "dev" ->
        [
          {Janitor, %{autostart: true}},
          server(Dutycycle.Supervisor, build_env),
          {Thermostat.Supervisor, initial}
        ]

      "test" ->
        [
          {Janitor, initial},
          server(Dutycycle.Server, build_env),
          {Thermostat.Supervisor, initial}
        ]

      "prod" ->
        [
          {Janitor, initial},
          erver(Dutycycle.Server, build_env),
          {Thermostat.Supervisor, initial}
        ]

      "standby" ->
        []

      _others ->
        []
    end
  end

  defp protocols(build_env) do
    case build_env do
      "dev" ->
        [
          {Fact.Supervisor, initial},
          {Mqtt.Supervisor, Map.put(initial, :autostart, true)}
        ]

      "standby" ->
        []

      _othets ->
        [{Fact.Supervisor, initial}, {Mqtt.Supervisor, initial}]
    end
  end

  defp server(Dutycycle.Supervisor, "test"),
    do: {Dutycyle.Supervisor, %{autostart: true, start_children: false}}

  defp server(Dutycycle.Supervisor, "prod"),
    do: {Dutycyle.Supervisor, %{autostart: true, start_children: true}}

  defp server(Dutycycle.Supervisor, _other_env),
    do: {Dutycyle.Supervisor, %{autostart: false, start_children: false}}

  defp support(build_env) do
    case build_env do
      "standby" -> []
      _others -> [{Janice.Scheduler, []}]
    end
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
