# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: :debug
  # level: :info
  level: :warn

config :mcp,
  feeds: [
    cmd: {"prod/mcr/f/command", :qos0},
    rpt: {"prod/mcr/f/report", :qos0},
    ota: {"prod/mcr/f/ota", :qos0}
  ]

config :mcp, Dutycycle, routine_check_ms: 1000

config :mcp, Janitor,
  switch_cmds: [purge: true, interval_mins: 2, older_than_hrs: 24 * 90, log: false],
  orphan_acks: [interval_mins: 1, older_than_mins: 1, log: true]

config :mcp, MessageSave,
  save: true,
  delete_older_than_hrs: 7 * 24

config :mcp, Mqtt.Client,
  log_dropped_msgs: true,
  broker: [
    # must be a char string (not binary) for emqttc
    host: '** set in prod.secret.exs **',
    port: 1883,
    client_id: "merc-prod",
    clean_sess: false,
    username: "** set in prod.secret.exs",
    password: "** set in prod.secret.exs",
    auto_resub: true,
    reconnect: 2
  ],
  timesync: [frequency: 60 * 1000, loops: 0, forever: true, log: false]

config :mcp, Mqtt.InboundMessage,
  periodic_log_first_ms: 60 * 60 * 1000,
  periodic_log_ms: 120 * 60 * 1000

config :mcp, Fact.Influx,
  database: "merc_repo",
  host: "** set in prod.secret.exs",
  auth: [
    method: :basic,
    username: "** set in prod.secret.exs",
    password: "** set in prod.secret.exs"
  ],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line,
  periodic_log_first_ms: 1 * 60 * 1000,
  periodic_log_ms: 15 * 60 * 1000

config :mcp, Mixtank.Control, control_temp_secs: 27

config :mcp, Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_prod",
  username: "merc_prod",
  password: "** set in prod.secret.exs",
  hostname: "** set in prod.secret.exs",
  pool_size: 20

config :mcp, Mcp.SoakTest,
  # don't start
  startup_delay_ms: 0,
  periodic_log_first_ms: 30 * 60 * 1000,
  periodic_log_ms: 60 * 60 * 1000,
  flash_led_ms: 3 * 1000

config :mcp, Switch, logCmdAck: false

config :mcp, Mcp.Chamber,
  autostart_wait_ms: 0,
  routine_check_ms: 1000

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
    github:
      {Ueberauth.Strategy.Github,
       [
         default_scope: "user,public_repo",
         # set URI redirect mismatch errors since we are
         # proxied behind nginx
         send_redirect_uri: false
       ]}
  ]

# Tell phoenix to actually serve endpoints when run as a release
config :phoenix, :serve_endpoints, true

import_config "prod.secret.exs"
