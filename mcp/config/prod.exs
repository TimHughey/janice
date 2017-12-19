# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: debug,
  level: :info

config :mcp, Command.Control,
  timesync_opts: [feed: "prod/mcr/f/command",
                  frequency: (5*60*1000),
                  # loops: 3,
                  forever: true,
                  log: true],
  rpt_feed: "prod/mcr/f/report",
  cmd_feed: "prod/mcr/f/command"

config :mcp, Dispatcher.InboundMessage,
  periodic_log_first_ms: (60 * 60 * 1000),
  periodic_log_ms: (120 * 60 * 1000),
  rpt_feed: "prod/mcr/f/report",
  cmd_feed: "prod/mcr/f/command"

config :mcp, Fact.Influx,
  database:  "mcp_repo",
  host:      "jophiel.wisslanding.com",
  auth:      [method: :basic, username: "updater", password: "mcp"],
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

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("MERC_DB_NAME"),
  username: System.get_env("MERC_DB_USER"),
  password: System.get_env("MERC_DB_PASSWD"),
  hostname: "jophiel.wisslanding.com",
  pool_size: 10

config :mcp, Mcp.Switch,
  logCmdAck: false

config :mcp, Janitor,
  purge_switch_cmds: [interval_mins: 2, older_than_hrs: 2, log: false]

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
  broker: [client_id: "mercurial-prod", clean_session: 1,
           username: "mqtt", password: "mqtt",
           host: "jophiel.wisslanding.com", port: 1883, ssl: false],
  feeds: [topics: ["prod/mcr/f/report"], qoses: [0]],
  rpt_feed: "prod/mcr/f/report",
  cmd_feed: "prod/mcr/f/command"

config :mcp, Web.Endpoint,
  http: [port: {:system, "PORT"}],
  load_from_system_env: true,
  url: [scheme: "https:", host: "www.wisslanding.com", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json",
  static_url: [path: "/mercurial"],
  server: true,
  # root: ".",
  version: Application.spec(:mcp, :vsn),
  secret_key_base: System.get_env("MERC_SECRET_KEY_BASE")

config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github,
        [default_scope: "user,public_repo", send_redirect_uri: false]}]

# Tell phoenix to actually serve endpoints when run as a release
config :phoenix, :serve_endpoints, true

# import_config "prod.secret.exs"
