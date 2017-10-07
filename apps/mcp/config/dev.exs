# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mcp, Mcp.Application,
  build_env: "#{Mix.env}"

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 1000,
  periodic_log_first_ms: (30 * 60 * 1000),
  periodic_log_ms: (60 * 60 * 1000),
  flash_led_ms: (1000)

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_test",
  username: "merc_test",
  password: System.get_env("MERC_TEST_DB_PASS"),
  hostname: "jophiel.wisslanding.com"

config :mcp, Mcp.Switch,
  logCmdAck: false

config :mcp, :ecto_repos, [Mcp.Repo]
