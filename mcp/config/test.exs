# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# useful functions
# must be set to variables since this is not a module
seconds = fn x -> x * 1000 end
minutes = fn x -> seconds.(60 * x) end

config :mcp,
  feeds: [
    cmd: {"test/mcr/f/command", 1},
    rpt: {"prod/mcr/f/report", 0}
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
    #       supervision tree to isolate restarts after crash
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
import_config "modules/msg_save_forward.exs"

config :mcp, Mqtt.Client,
  log_dropped_msg: true,
  runtime_metrics: true,
  tort_opts: [
    client_id: "janice-test",
    user_name: "mqtt",
    password: "mqtt",
    server:
      {Tortoise.Transport.Tcp, host: "jophiel.wisslanding.com", port: 1883},
    keep_alive: 15
  ],
  timesync: [frequency: {:secs, 5}, loops: 5, forever: false, log: false]

config :mcp, Mqtt.Inbound,
  log: [
    engine_metrics: false
  ],
  periodic_log: [enable: false, first: {:secs, 10}, repeat: {:mins, 5}]

config :mcp, Fact.Influx,
  database: "jan_test",
  host: "jophiel.wisslanding.com",
  auth: [method: :basic, username: "jan_test", password: "jan_test"],
  http_opts: [insecure: true],
  pool: [max_overflow: 10, size: 10, timeout: 60_000, max_connections: 30],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line

config :mcp, Repo,
  username: "jan_test",
  password: "jan_test",
  database: "jan_test",
  hostname: "live.db.wisslanding.com",
  pool_size: 10

config :mcp, PulseWidthCmd,
  orphan: [
    at_startup: true,
    sent_before: [seconds: 1],
    older_than: [minutes: 1],
    log: false
  ],
  purge: [
    at_startup: true,
    interval: [minutes: 2],
    older_than: [days: 30],
    log: false
  ]

config :mcp, Switch.Command,
  # NOTE:  older_than lists are passed to Timex to create a
  #        shifted DateTime in UTC
  orphan: [
    at_startup: true,
    sent_before: [seconds: 1],
    log: true
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
       task: {Janice.Jobs, :touch_file, ["/tmp/janice-test.touch"]},
       run_strategy: Quantum.RunStrategy.Local
     ]}

    # EXAMPLES:
    #
    # Every 15 minutes
    # {"*/15 * * * *",   fn -> System.cmd("rm", ["/tmp/tmp_"]) end},
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    # {"0 18-6/2 * * *", fn -> :mnesia.backup('/var/backup/mnesia') end},
    # Runs every midnight:
    # {"@daily",         {Backup, :backup, []}}
  ]

config :mcp, Mcp.SoakTest,
  # don't start
  startup_delay: {:ms, 0},
  periodic_log_first: {:mins, 30},
  periodic_log: {:mins, 15},
  flash_led: {:secs, 1}
