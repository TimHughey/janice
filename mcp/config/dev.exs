# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# useful functions
# must be set to variables since this is not a module
seconds = fn x -> x * 1000 end
minutes = fn x -> seconds.(60 * x) end

config :logger,
  # level: :debug
  # level: :warn
  level: :info

config :mcp,
  feeds: [
    cmd: {"dev/mcr/f/command", :qos0},
    rpt: {"dev/mcr/f/report", :qos0}
  ]

config(:mcp, Janitor,
  switch_cmds: [
    purge: true,
    interval: {:mins, 2},
    older_than: {:weeks, 1},
    log: false
  ],
  orphan_acks: [interval: {:mins, 1}, older_than: {:mins, 1}, log: true]
)

config :mcp, MessageSave,
  save: true,
  delete: [all_at_startup: false, older_than: {:hrs, 12}]

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
    logger: :warning,
    reconnect: {3, 60, 30}
  ],
  timesync: [frequency: {:mins, 1}, loops: 5, forever: true, log: false]

config :mcp, Mqtt.InboundMessage,
  log: [
    engine_metrics: false
  ],
  periodic_log: [
    enable: false,
    first: {:mins, 5},
    repeat: {:hrs, 1}
  ]

config :mcp, Fact.Influx,
  database: "jan_dev",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "jan_test", password: "jan_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line

config :mcp, Repo,
  migration_timestamps: [:utc_datetime_usec],
  database: "jan_dev",
  username: "jan_dev",
  password: "jan_dev",
  # hostname: "127.0.0.1",
  hostname: "live.db.wisslanding.com",
  pool_size: 10

# run_strategy = {Quantum.RunStrategy.All, [:"mcp-dev@jophiel.wisslanding.com"]}
run_strategy = Quantum.RunStrategy.Local

base_jobs = [
  {:touch,
   [
     schedule: {:cron, "* * * * *"},
     task: {Janice.Jobs, :touch_file, ["/tmp/janice-dev.touch"]},
     run_strategy: run_strategy
   ]}
]

additional_jobs = []

# additional_jobs = [{:germination_on,
#  [
#    schedule: {:cron, "*/2 8-19 * * *"},
#    task: {Janice.Jobs, :switch_control, ["germination_light", true]},
#    run_strategy: Quantum.RunStrategy.Local
#  ]},
# {:germination_off,
#  [
#    schedule: {:cron, "*/2 20-7 * * *"},
#    task: {Janice.Jobs, :switch_control, ["germination_light", false]},
#    run_strategy: Quantum.RunStrategy.Local
#  ]},
# {:germination_heat,
#  [
#    schedule: {:cron, "*/2 * * * *"},
#    task: {Janice.Jobs, :switch_control, ["germination_heat", true]},
#    run_strategy: Quantum.RunStrategy.Local
#  ]}]

jobs = base_jobs ++ additional_jobs

config :mcp, Janice.Scheduler, jobs: jobs

config :mcp, Mcp.SoakTest,
  # don't start
  startup_delay: {:ms, 0},
  periodic_log_first: {:mins, 30},
  periodic_log: {:hrs, 1},
  flash_led: {:secs, 3}

config :mcp, Switch, logCmdAck: false
