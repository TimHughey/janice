# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mcp, Mcp.Application,
  build_env: "#{Mix.env}"

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 0,  # don't start
  periodic_log_first_ms: (30 * 60 * 1000),
  periodic_log_ms: (60 * 60 * 1000),
  flash_led_ms: (3 * 1000)

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("MERC_DB_NAME"),
  username: System.get_env("MERC_DB_USER"),
  password: System.get_env("MERC_DB_PASSWD"),
  hostname: "jophiel.wisslanding.com",
  pool_size: 10

config :mcp, Mcp.Switch,
  logCmdAck: false

config :mcp, Mcp.Janitor,
  startup_delay_ms: 12_000,
  purge_switch_cmds_interval_minutes: 2,
  purge_switch_cmds_older_than_hours: 3

config :mcp, Mcp.Chamber,
  autostart_wait_ms: 0,
  routine_check_ms: 1000

config :mcp, Mcp.Mixtank,
  autostart_wait_ms: 1000,
  control_temp_ms: 1000,
  activate_ms: 1000,
  manage_ms: 1000

config :mcp, Mcp.Dutycycle,
  autostart_wait_ms: 0,
  routine_check_ms: 1000

config :mcp, :ecto_repos, [Mcp.Repo]
