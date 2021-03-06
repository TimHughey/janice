# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: :debug
  # level: :warn
  level: :info

config :mcp,
  feeds: [
    cmd: {"dev/mcr/f/command", 1},
    rpt: {"dev/mcr/f/report", 0}
  ]

config :mcp,
  # overrides from config.exs
  protocol_supervisors: [
    {Fact.Supervisor, [log: [init: false]]}
  ],
  worker_supervisors: [
    # DynamicSupervisors
    {Dutycycle.Supervisor, [start_workers: false]},
    {Thermostat.Supervisor, [start_workers: false]}
  ]

#
# NOTE: uncomment to enable saving/forwarding of messages sent and/or
#       recv'd via MQTT
#
# import_config "modules/msg_save_enable.exs"
# import_config "modules/msg_save_forward.exs"

config :mcp, Fact.Influx,
  database: "jan_dev",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "jan_test", password: "jan_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 5, timeout: 150_000, max_connections: 10],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line

config :mcp, Mcp.SoakTest,
  # don't start
  startup_delay: {:ms, 0},
  periodic_log_first: {:mins, 30},
  periodic_log: {:hrs, 1},
  flash_led: {:secs, 3}

config :mcp, Mqtt.Client,
  log_dropped_msgs: true,
  tort_opts: [
    client_id: "janice-#{Mix.env()}",
    user_name: "mqtt",
    password: "mqtt",
    server:
      {Tortoise.Transport.Tcp, host: "jophiel.wisslanding.com", port: 1883},
    keep_alive: 15
  ],
  timesync: [frequency: {:mins, 1}, loops: 5, forever: true, log: false],
  log: [init: false]

config :mcp, Mqtt.Inbound,
  additional_message_flags: [
    switch_redesign: true
  ]

config :mcp, PulseWidthCmd,
  orphan: [
    at_startup: true,
    sent_before: [seconds: 10],
    log: true
  ],
  purge: [
    at_startup: true,
    interval: [minutes: 2],
    older_than: [days: 30],
    log: false
  ]

config :mcp, Repo,
  database: "jan_dev",
  username: "jan_dev",
  password: "jan_dev",
  port: 15432,
  hostname: "dev.db.wisslanding.com",
  pool_size: 10

config :mcp, Switch.Command,
  # NOTE:  older_than lists are passed to Timex to create a
  #        shifted DateTime in UTC
  orphan: [
    at_startup: true,
    sent_before: [seconds: 10],
    log: false
  ],
  purge: [
    at_startup: true,
    interval: [minutes: 2],
    older_than: [days: 30],
    log: true
  ]

config :mcp, Janice.Scheduler,
  jobs: [
    # Every minute
    {:touch,
     [
       schedule: {:cron, "* * * * *"},
       task: {Janice.Jobs, :touch_file, ["/tmp/janice-dev.touch"]},
       run_strategy: Quantum.RunStrategy.Local
     ]},
    {:purge_readings,
     [
       schedule: {:cron, "22,56 * * * *"},
       task: {Janice.Jobs, :purge_readings, [[days: -30]]},
       run_strategy: Quantum.RunStrategy.Local
     ]}
  ]
