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
influx = %{db: "mcp_test", host: "jophiel.wisslanding.com:8086",
           user: "mcp_test", pass: "mcp_test"}

config :distillery, no_warn_missing: [:elixir_make, :distillery]

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "mcp_test",
  username: "mcp_test",
  password: System.get_env("MCP_DB_PASS_T"),
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

    Elixir.Mcp.Owfs =>
      %{name: {scope, Mcp.Owfs},
        run_node: run_node,
        path: "/var/lib/owfs/mnt", sensor_regex: "ts_|hs_",
        kickstart_wait_ms: 10,
        call_timeout_ms: 5000,
        temp_refresh_ms: 9_000,
        write_max_retries: 5, write_retry_ms: 100},

    Elixir.Mcp.Proxr =>
      %{name: {scope, Mcp.Proxr},
        run_node: run_node,
        relay_dev: "/dev/ttyUSB0",
        kickstart: false, kickstart_wait_ms: 1,
        call_timeout_ms: 2000},

    Elixir.Mcp.ProxrBoy =>
      %{name: {scope, Mcp.ProxrBoy},
        run_node: run_node,
        call_timeout_ms: 1000,
        kickstart: false, kickstart_wait_ms: 100,
        refresh_ms: 500},

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
        doctor: :computer, yesterday: "tomorrow"},

    Elixir.Mcp.I2cSensor =>
      %{name: {scope, Mcp.I2cSensor},
        run_node: run_node,
        kickstart_wait_ms: 15,
        mode: i2c_sensor_mode,
        call_timeout_ms: 5000,
        temp_refresh_ms: 10_000,
        i2c_device: "i2c-1",
        i2c_use_multiplexer: i2c_use_multiplexer,
        sht: %{address: 0x44, wait_ms: 20, name: "i2c_sht"},
        hih: %{address: 0x27, wait_ms: 100, name: "i2c_hih"},
        am2315: %{address: 0x5c, wait_ms: 0, name: "i2c_am2315",
                   failure_ms: 10, pwr_sw: "am2315_pwr", pwr_wait_ms: 2000}}}
