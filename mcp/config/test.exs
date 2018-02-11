# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mcp, feeds: [cmd: {"test/mcr/f/command", :qos0}, rpt: {"test/mcr/f/report", :qos0}]

config :command, Command.Control,
  startup_delay_ms: 200,
  periodic_timesync_ms: 5 * 60 * 1000,
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :dispatcher, Mqtt.InboundMessage,
  log_reading: true,
  startup_delay_ms: 200,
  periodic_log_first_ms: 30_000,
  periodic_log_ms: 10 * 60 * 1000,
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :fact, Fact.Influx,
  database: "mcp_repo",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "mcp_test", password: "mcp_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line,
  startup_delay_ms: 1000,
  periodic_log_first_ms: 1 * 60 * 1000,
  periodic_log_ms: 15 * 60 * 1000

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 1000,
  periodic_log_first_ms: 1 * 60 * 1000,
  periodic_log_ms: 15 * 50 * 1000,
  flash_led_ms: 1000

config :mcp, Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "merc_test",
  password: "merc_test",
  database: "merc_test",
  hostname: "jophiel.wisslanding.com",
  pool_size: 10

config :mcp, Switch, logCmdAck: false

config :mcp, Mcp.Janitor,
  startup_delay_ms: 12_000,
  purge_switch_cmds_interval_minutes: 2,
  purge_switch_cmds_older_than_hours: 3

config :mcp, Mcp.Chamber,
  autostart_wait_ms: 100,
  routine_check_ms: 1000

config :mcp, Mcp.Mixtank,
  autostart_wait_ms: 100,
  control_temp_ms: 1000,
  activate_ms: 1000,
  manage_ms: 1000

config :mcp, Mcp.Dutycycle,
  autostart_wait_ms: 100,
  routine_check_ms: 1000

config :mqtt, Mqtt.Client,
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
  ]

config :mcp, Web.Endpoint,
  http: [port: 4001],
  server: false

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
