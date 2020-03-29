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

config :scribe, style: Scribe.Style.Psql

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
  ]

config :mcp, Mcp.Application, log: [init: false]

config :mcp, Janice.Scheduler,
  global: true,
  run_strategy: Quantum.RunStrategy.Local,
  timezone: "America/New_York"

config(:mcp, Janitor,
  # modules to call at startup (typically to purge cmds or ack orphans)
  at_startup: [{PulseWidthCmd, :purge_cmds}],
  log: [init: false],
  metrics_frequency: [orphan: [minutes: 5], switch_cmd: [minutes: 5]],
  orphan_acks: [interval: [minutes: 1], older_than: [minutes: 1], log: false],
  switch_cmds: [
    purge: true,
    interval: [minutes: 2],
    older_than: [days: 30],
    log: false
  ]
)

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
