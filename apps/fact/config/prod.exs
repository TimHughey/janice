# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :fact, Fact.Application,
  build_env: "#{Mix.env}"

config :fact, Fact.Influx,
  database:  "mcp_repo",
  host:      "jophiel.wisslanding.com",
  auth:      [method: :basic, username: "updater", password: "mcp"],
  http_opts: [insecure: true],
  pool:      [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port:      8086,
  scheme:    "http",
  writer:    Instream.Writer.Line,
  startup_delay_ms: 1000,
  periodic_log_first_ms: (1 * 60 * 1000),
  periodic_log_ms: (15 * 60 * 1000)
