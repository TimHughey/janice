# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# set variables at top of config file to allow the bulk of the config to be
# consistent for all envs
node_id = "mcp"
{raw_host, 0} = System.cmd("hostname", ["-f"])
host = String.trim_trailing(raw_host)
run_node = String.to_atom("#{Mix.env()}@#{host}")
autostart = :false
scope = :local
max_restarts = 1
max_seconds = 1
auto_populate = :true
i2c_sensor_mode = :simulate
i2c_use_multiplexer = :false
influx = %{db: "merc_test", host: "jophiel.wisslanding.com:8086",
           user: "merc_test", pass: "merc_test"}

config :distillery, no_warn_missing: [:elixir_make, :distillery]

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_test",
  username: "merc_test",
  password: System.get_env("MERC_DB_PASS_T"),
  hostname: "gabriel.wisslanding.com"

#
# NOTHING BELOW THIS POINT SHOULD BE DIFFERENT ACROSS envs
#
config :mcp, :ecto_repos, [Mcp.Repo]

config :logger, level: :info

config :mcp,
  autostart: autostart,
  connect_nodes: [],
  genservers: %{
    Elixir.Mcp.Supervisor =>
      %{name: {:local, Mcp.Supervisor},
        opts: [max_restarts: max_restarts, max_seconds: max_seconds]},

    Elixir.Mcp.Chamber =>
      %{name: {scope, Mcp.Chamber},
        run_node: run_node,
        auto_populate: auto_populate,
        kickstart_wait_ms: 100,
        routine_check_ms: 1000},

    Elixir.Mcp.Mixtank =>
      %{name: {scope, Mcp.Mixtank},
        run_node: run_node,
        control_temp_ms: 1000, activate_ms: 1000, manage_ms: 1000},

    Elixir.Mcp.Switch =>
      %{name: {scope, Mcp.Switch},
        run_node: run_node,
        kickstart_wait_ms: 11,
        refresh_ms: 10_000},

    Elixir.Mcp.Influx =>
      %{name: {:local, Mcp.Influx},
        run_node: run_node,
        db: influx.db, db_host: influx.host,
        db_user: influx.user, db_pass: influx.pass,
        exec_env: Mix.env(), node_id: node_id},

    Elixir.Mcp.Dutycycle =>
      %{name: {scope, Mcp.Dutcycle},
        run_node: run_node,
        kickstart_wait_ms: 100,
        routine_check_ms: 1000},

    Elixir.Mcp.GenServerTest.Local =>
      %{name: {scope, Mcp.GenServerTest.Local},
        doctor: :computer, yesterday: "tomorrow"},

    Elixir.Mcp.GenServerTest.Global =>
      %{name: {:global, Mcp.GenServerTest.Global},
        doctor: :computer, yesterday: "tomorrow"}}
