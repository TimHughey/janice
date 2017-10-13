# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mcp, Mcp.Application,
  build_env: "#{Mix.env}"

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 1000,
  periodic_log_first_ms: (1 * 60 * 1000),
  periodic_log_ms: (15 * 50 * 1000),
  flash_led_ms: 1000

config :db, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "foo",
  password: "12345",
  database: "myproject_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :mcp, Mcp.Switch,
  logCmdAck: false

config :mcp, :ecto_repos, [Mcp.Repo]
