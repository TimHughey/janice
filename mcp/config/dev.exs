# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: :debug
  # level: :warn
  level: :info

config :mcp,
  feeds: [
    cmd: {"dev/mcr/f/command", :qos0},
    rpt: {"dev/mcr/f/report", :qos0},
    ota: {"dev/mcr/f/ota", :qos0}
  ]

config :mcp, Dutycycle, routine_check_ms: 1000

config :mcp, Janitor,
  switch_cmds: [purge: true, interval_mins: 2, older_than_hrs: 24 * 7, log: true],
  orphan_acks: [interval_mins: 1, older_than_mins: 1, log: false]

config :mcp, MessageSave,
  save: true,
  delete: [all_at_startup: false, older_than_hrs: 12]

config :mcp, Mqtt.Client,
  log_dropped_msgs: true,
  broker: [
    host: 'jophiel.wisslanding.com',
    client_id: "janice-dev",
    clean_sess: true,
    # keepalive: 30_000,
    username: "mqtt",
    password: "mqtt",
    auto_resub: true,
    reconnect: 2
  ],
  timesync: [frequency: 1 * 1000, loops: 5, forever: true, log: false]

config :mcp, Mqtt.InboundMessage,
  periodic_log_first_ms: 60 * 60 * 1000,
  periodic_log_ms: 120 * 60 * 1000

config :mcp, Fact.Influx,
  database: "jan_dev",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "jan_test", password: "jan_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line,
  periodic_log_first_ms: 1 * 60 * 1000,
  periodic_log_ms: 15 * 60 * 1000

config :mcp, Mixtank.Control, control_temp_secs: 600

config :mcp, Repo,
  migration_timestamps: [:utc_datetime_usec],
  database: "jan_dev",
  username: "jan_dev",
  password: "jan_dev",
  # hostname: "127.0.0.1",
  hostname: "jophiel.wisslanding.com",
  pool_size: 10

config :mcp, Janice.Scheduler,
  global: true,
  jobs: [
    # Every minute
    {:touch,
     [
       schedule: {:cron, "* * * * *"},
       task: {Janice.Jobs, :touch_file, ["/tmp/janice-file"]},
       run_strategy: Quantum.RunStrategy.Local
     ]},
    {:germination_on,
     [
       schedule: {:cron, "*/2 8-19 * * *"},
       task: {Janice.Jobs, :switch_control, ["germination_light", true]},
       run_strategy: Quantum.RunStrategy.Local
     ]},
    {:germination_off,
     [
       schedule: {:cron, "*/2 20-7 * * *"},
       task: {Janice.Jobs, :switch_control, ["germination_light", false]},
       run_strategy: Quantum.RunStrategy.Local
     ]},
    {:germination_heat,
     [
       schedule: {:cron, "*/2 * * * *"},
       task: {Janice.Jobs, :switch_control, ["germination_heat", true]},
       run_strategy: Quantum.RunStrategy.Local
     ]}
  ]

config :mcp, Mcp.SoakTest,
  # don't start
  startup_delay_ms: 0,
  periodic_log_first_ms: 30 * 60 * 1000,
  periodic_log_ms: 60 * 60 * 1000,
  flash_led_ms: 3 * 1000

config :mcp, Switch, logCmdAck: false
