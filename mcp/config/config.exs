# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger,
  console: [metadata: [:module], format: "$time $metadata$message\n"],
  backends: [:console],
  level: :info,
  compile_time_purge_matching: [
    [application: :mcp, level_lower_than: :info],
    [application: :swarm, level_lower_than: :error]
  ]

config :scribe, style: Scribe.Style.GithubMarkdown

# General application configuration
config :mcp,
  ecto_repos: [Repo],
  build_env: "#{Mix.env()}",
  namespace: Web,
  generators: [context_app: false],
  # default settings for dev and test, must override in prod
  feeds: [
    cmd: {"dev/mcr/f/command", 1},
    rpt: {"dev/mcr/f/report", 0}
  ],
  # Supervision Tree and Initial Opts (listed in startup order)
  sup_tree: [
    {Repo, []},
    {Janitor.Supervisor, []},
    :core_supervisors,
    # TODO: once the Supervisors below are implemented remove the following
    #       specific list of supervisors
    :protocol_supervisors,
    :support_workers,
    :worker_supervisors,
    :misc_workers,
    :agnus
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
    {Fact.Supervisor, [log: [init: false, init_args: false]]},
    {Mqtt.Supervisor, []}
  ],
  support_workers: [],
  worker_supervisors: [
    # DynamicSupervisors
    {Dutycycle.Supervisor, [start_workers: true]},
    {Thermostat.Supervisor, [start_workers: true]}
  ],
  misc_workers: [
    {Janice.Scheduler, []}
  ],
  agnus: [
    {Agnus.Supervisor, []}
  ]

config :mcp, Agnus.DayInfo,
  log: [init: false, init_args: false],
  tz: "America/New_York",
  api: [
    url: "https://api.sunrise-sunset.org",
    lat: 40.2108,
    lng: -74.011
  ]

config :mcp, Agnus.Supervisor, log: [init: false, init_args: false]

config :mcp, Mcp.Application, log: [init: false]

config :mcp, Janice.Scheduler,
  global: true,
  run_strategy: Quantum.RunStrategy.Local,
  timezone: "America/New_York"

config :mcp, Janitor,
  log: [init: true, init_args: false],
  metrics_frequency: [orphan: [minutes: 5], switch_cmd: [minutes: 5]]

config :mcp, Janitor.Supervisor, log: [init: true, init_args: false]

config :mcp, MessageSave,
  log: [init: false],
  save: false,
  save_opts: [],
  forward: false,
  forward_opts: [in: [feed: {"dev/mcr/f/report", 0}]],
  purge: [all_at_startup: true, older_than: [minutes: 20], log: false]

config :mcp, Mqtt.Inbound,
  additional_message_flags: [
    log_invalid_readings: true,
    log_roundtrip_times: true
  ],
  periodic_log: [
    enable: false,
    first: {:mins, 5},
    repeat: {:hrs, 60}
  ],
  log_reading: false,
  temperature_msgs: {Sensor, :external_update},
  remote_msgs: {Remote, :external_update},
  pwm_msgs: {PulseWidth, :external_update}

config :mcp, OTA,
  url: [
    host: "www.wisslanding.com",
    uri: "janice/mcr_esp/firmware",
    fw_file: "latest-mcr_esp.bin"
  ]

config :mcp, Repo,
  migration_timestamps: [type: :utc_datetime_usec],
  adapter: Ecto.Adapters.Postgres

config :mcp, Switch.Device, log: [cmd_ack: false]

import_config "#{Mix.env()}.exs"
