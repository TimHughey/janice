# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :info
# level: :warn
# level: :info

config :mcp,
  feeds: [
    cmd: {"test/mcr/f/command", :qos0},
    rpt: {"test/mcr/f/report", :qos0},
    ota: {"test/mcr/f/ota", :qos0}
  ]

config :mcp, Mcp.Dutycycle, routine_check_ms: 1000

config :mcp, Janitor,
  switch_cmds: [purge: true, interval_mins: 2, older_than_hrs: 24 * 7, log: true],
  orphan_acks: [interval_mins: 1, older_than_mins: 1, log: true]

config :mcp, MessageSave,
  save: true,
  delete_older_than_hrs: 12

config :mcp, Mqtt.Client,
  log_dropped_msg: true,
  broker: [
    host: 'jophiel.wisslanding.com',
    port: 1883,
    client_id: "merc-test",
    clean_sess: true,
    username: "mqtt",
    password: "mqtt",
    auto_resub: true,
    reconnect: 2
  ],
  timesync: [frequency: 5 * 1000, loops: 5, forever: false, log: false]

config :mcp, Mqtt.InboundMessage,
  log_reading: true,
  startup_delay_ms: 200,
  periodic_log_first_ms: 30_000,
  periodic_log_ms: 10 * 60 * 1000,
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :mcp, Fact.Influx,
  database: "merc_test",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "merc_test", password: "merc_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 10, timeout: 60_000, max_connections: 30],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line

config :mcp, Mixtank.Control, control_temp_ms: 1000

config :mcp, Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "merc_test",
  password: "merc_test",
  database: "merc_test",
  hostname: "jophiel.wisslanding.com",
  pool_size: 10

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 1000,
  periodic_log_first_ms: 1 * 60 * 1000,
  periodic_log_ms: 15 * 50 * 1000,
  flash_led_ms: 1000

config :mcp, Switch, logCmdAck: false

config :mcp, Mcp.Chamber,
  autostart_wait_ms: 0,
  routine_check_ms: 1000

config :mcp, Web.Endpoint,
  http: [port: 4000],
  # url: [scheme: "https", url: "www.wisslanding.com", port: 443],
  static_url: [path: "/mercurial"],
  debug_errors: true,
  check_origin: false

config :ueberauth, Ueberauth,
  providers: [
    identity:
      {Ueberauth.Strategy.Identity,
       [
         callback_methods: ["POST"],
         callback_path: "/mercurial/auth/identity/callback",
         uid_field: :username,
         nickname_field: :username
       ]}
  ]

config :phoenix, :stacktrace_depth, 20
