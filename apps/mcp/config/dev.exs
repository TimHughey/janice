# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :distillery, no_warn_missing: [:elixir_make, :distillery]

config :mcp, Mcp.Application,
  build_env: "#{Mix.env}"

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_test",
  username: "merc_test",
  password: System.get_env("MERC_TEST_DB_PASS"),
  hostname: "gabriel.wisslanding.com"

config :mcp, :ecto_repos, [Mcp.Repo]

config :logger,
  backends: [:console],
  level: :info

config :logger, :console,
  metadata: [:module],
  format: "$time $metadata$message\n"
