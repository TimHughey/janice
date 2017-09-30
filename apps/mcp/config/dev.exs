# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

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
