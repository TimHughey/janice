# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: debug,
  level: :info

config :mcp, Command.Control,
  timesync_opts: [feed: "mcr/f/command",
                  frequency: (5*60*1000),
                  # loops: 3,
                  forever: true,
                  log: false],
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :mcp, Dispatcher.InboundMessage,
  periodic_log_first_ms: (60 * 60 * 1000),
  periodic_log_ms: (120 * 60 * 1000),
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :mcp, Fact.Influx,
  database:  "mcp_repo",
  host:      "jophiel.wisslanding.com",
  auth:      [method: :basic, username: "mcp_test", password: "mcp_test"],
  http_opts: [insecure: true],
  pool:      [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port:      8086,
  scheme:    "http",
  writer:    Instream.Writer.Line,
  periodic_log_first_ms: (1 * 60 * 1000),
  periodic_log_ms: (15 * 60 * 1000)

config :mcp, Mcp.SoakTest,
  startup_delay_ms: 0,
  periodic_log_first_ms: (30 * 60 * 1000),
  periodic_log_ms: (60 * 60 * 1000),
  flash_led_ms: (3 * 1000)

config :mcp, Mcp.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "merc_dev",
  username: "merc_dev",
  password: "merc_dev",
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
  broker: [client_id: "mercurial-dev", clean_session: 1,
           username: "mqtt", password: "mqtt",
           host: "jophiel.wisslanding.com", port: 1883, ssl: false],
  feeds: [topics: ["mcr/f/report"], qoses: [0]],
  rpt_feed: "dev/mcr/f/report",
  cmd_feed: "dev/mcr/f/command"

config :mcp, Web.Endpoint,
  http: [port: 4000],
  #url: [scheme: "https", url: "www.wisslanding.com", port: 443],
  static_url: [path: "/mercurial"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../assets", __DIR__)]],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/web/views/.*(ex)$},
      ~r{lib/web/templates/.*(eex)$}
    ]
  ]

config :ueberauth, Ueberauth,
  providers: [
    identity: {Ueberauth.Strategy.Identity, [
        callback_methods: ["POST"],
        callback_path: "/mercurial/auth/identity/callback",
        uid_field: :username,
        nickname_field: :username,
      ]}
  ]

config :phoenix, :stacktrace_depth, 20
