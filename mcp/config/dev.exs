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
    cmd: {"dev/mcr/f/command", 1},
    rpt: {"dev/mcr/f/report", 0}
  ]

config :mcp,
  # listed in startup order
  sup_tree: [
    {Repo, []},
    :core_supervisors,
    # TODO: once the Supervisors below are implemented remove the following
    #       specific list of supervisors
    :protocol_supervisors,
    :support_workers,
    :worker_supervisors,
    :misc_workers
  ],
  core_supervisors: [
    # TODO: implement the Supervisors below to create a 'proper'
    #       supervisom tree that does not restart servers uncessary
    # {Protocols.Supervisor, []},
    # {Support.Supervisor, []},
    # {Workers.Supervisor, []},
    # {Misc.Supervisors, []}
  ],
  protocol_supervisors: [
    {Fact.Supervisor, %{}},
    {Mqtt.Supervisor, %{autostart: true}}
  ],
  support_workers: [
    {Janitor, %{autostart: true}}
  ],
  worker_supervisors: [
    # DynamicSupervisors
    {Dutycycle.Supervisor, %{start_workers: false}},
    {Thermostat.Supervisor, %{start_workers: false}}
  ],
  misc_workers: [
    {Janice.Scheduler, []}
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
  timesync: [frequency: {:mins, 1}, loops: 5, forever: true, log: false]

config :mcp, Repo,
  database: "jan_dev",
  username: "jan_dev",
  password: "jan_dev",
  # hostname: "127.0.0.1",
  hostname: "live.db.wisslanding.com",
  pool_size: 10

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
