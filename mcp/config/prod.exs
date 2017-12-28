# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: debug,
  level: :info

config :mcp,
  feeds: [cmd: "prod/mcr/f/command", rpt: "prod/mcr/f/report"]

config :mcp, MessageSave,
  save: true,
  delete_older_than_hrs: (7 * 24)

config :mcp, Command.Control,
  timesync_opts: [frequency: (60*1000), # millisecs
                  # loops: 3,
                  forever: true,
                  log: false]

config :mcp, Dispatcher.InboundMessage,
  periodic_log_first_ms: (60 * 60 * 1000),
  periodic_log_ms: (120 * 60 * 1000)

config :mcp, Fact.Influx,
  database:  "mcp_repo",
  host:      "** set in prod.secret.exs",
  auth:      [method: :basic,
              username: "** set in prod.secret.exs",
              password: "** set in prod.secret.exs"],
  http_opts: [insecure: true],
  pool:      [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port:      8086,
  scheme:    "http",
  writer:    Instream.Writer.Line,
  periodic_log_first_ms: (1 * 60 * 1000),
  periodic_log_ms: (15 * 60 * 1000)

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 0,  # don't start
  periodic_log_first_ms: (30 * 60 * 1000),
  periodic_log_ms: (60 * 60 * 1000),
  flash_led_ms: (3 * 1000)

config :mcp, Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_prod",
  username: "merc_prod",
  password: "** set in prod.secret.exs",
  hostname: "** set in prod.secret.exs",
  pool_size: 10

config :mcp, Switch,
  logCmdAck: false

config :mcp, Janitor,
  purge_switch_cmds: [interval_mins: 2, older_than_hrs: (24*7), log: true]

config :mcp, Mcp.Chamber,
  autostart_wait_ms: 0,
  routine_check_ms: 1000

config :mcp, Mixtank,
  control_temp_ms: 1000,
  activate_ms: 1000,
  manage_ms: 1000

config :mcp, Dutycycle,
  routine_check_ms: 1000

config :mcp, Mqtt.Client,
  broker: [client_id: "mercurial-prod",
            clean_session: 1,
            username: "** set in prod.secret.exs",
            password: "** set in prod.secret.exs",
            host: "** set in prod.secret.exs",
            port: 1883, ssl: false],
            feeds: [topics: ["prod/mcr/f/report"], qoses: [0]] # subscribe

config :mcp, Web.Endpoint,
  # http: [port: {:system, "PORT"}],
  http: [port: 4009],
  load_from_system_env: true,
  url: [scheme: "https:", host: "www.wisslanding.com", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json",
  static_url: [path: "/mercurial"],
  server: true,
  # root: ".",
  version: Application.spec(:mcp, :vsn)
  # secret_key_base: set in prod.secret.exs

config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github,
              [default_scope: "user,public_repo",
               # set URI redirect mismatch errors since we are
               # proxied behind nginx
               send_redirect_uri: false] }]

# Tell phoenix to actually serve endpoints when run as a release
config :phoenix, :serve_endpoints, true

import_config "prod.secret.exs"
