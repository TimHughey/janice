# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  # level: :debug
  # level: :warn
  level: :info

config :mcp,
  feeds: [
    cmd: {"prod/mcr/f/command", 1},
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
    {Dutycycle.Supervisor, %{start_workers: true}},
    {Thermostat.Supervisor, %{start_workers: true}}
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

config :mcp, Mqtt.Client,
  log_dropped_msgs: true,
  tort_opts: [
    client_id: "janice-prod",
    user_name: "** set in prod.secret.exs",
    password: "** set in prod.secret.exs",
    server:
      {Tortoise.Transport.Tcp, host: "** set in prod.secret.exs", port: 1883},
    keep_alive: 15
  ],
  # timesync also keeps the MQTT client connection alive
  # the MQTT spec requires both sending and receiving to prevent disconnects
  timesync: [frequency: {:mins, 2}, loops: 0, forever: true, log: false]

config :mcp, Mqtt.Inbound,
  additional_message_flags: [
    log_invalid_readings: true,
    log_roundtrip_times: true
  ],
  periodic_log: [
    enable: false,
    first: {:mins, 5},
    repeat: {:hrs, 60}
  ]

config :mcp, Fact.Influx,
  database: "merc_repo",
  host: "** set in prod.secret.exs",
  auth: [
    method: :basic,
    username: "** set in prod.secret.exs",
    password: "** set in prod.secret.exs"
  ],
  http_opts: [insecure: true],
  pool: [max_overflow: 15, size: 10, timeout: 150_000, max_connections: 25],
  port: 8086,
  scheme: "http",
  writer: Instream.Writer.Line

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

config :mcp, Repo,
  database: "jan_prod",
  username: "jan_prod",
  password: "** set in prod.secret.exs",
  hostname: "** set in prod.secret.exs",
  pool_size: 20

config :mcp, Switch.Command,
  # NOTE:  older_than lists are passed to Timex to create a
  #        shifted DateTime in UTC
  orphan: [
    at_startup: true,
    sent_before: [seconds: 12],
    older_than: [minutes: 1],
    log: false
  ],
  purge: [
    at_startup: true,
    interval: [minutes: 2],
    older_than: [days: 30],
    log: false
  ]

run_strategy = {Quantum.RunStrategy.All, [:"mcp-prod@jophiel.wisslanding.com"]}

config :mcp, Janice.Scheduler,
  jobs: [
    # Every minute
    {:touch,
     [
       schedule: {:cron, "* * * * *"},
       task: {Janice.Jobs, :touch_file, ["/tmp/janice-prod.touch"]},
       run_strategy: run_strategy
     ]},
    {:purge_readings,
     [
       schedule: {:cron, "22,56 * * * *"},
       task: {Janice.Jobs, :purge_readings, [[days: -30]]},
       run_strategy: run_strategy
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
  periodic_log: {:hrs, 1},
  flash_led: {:secs, 3}

config :mcp, Switch, logCmdAck: false

import_config "prod.secret.exs"
