# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger,
  console: [metadata: [:module], format: "$time $metadata$message\n"],
  backends: [:console],
  level: :info

config :scribe, style: Scribe.Style.Psql

# General application configuration
config :mcp,
  ecto_repos: [Repo],
  build_env: "#{Mix.env()}",
  namespace: Web,
  generators: [context_app: false],
  # default settings for dev and test, must override in prod
  feeds: [
    cmd: {"dev/mcr/f/command", 0},
    rpt: {"dev/mcr/f/report", 0},
    ota: {"prod/mcr/f/ota", 0}
  ]

config :mcp, Mcp.Application, log: [init: false]

config :mcp, Janice.Scheduler,
  global: true,
  run_strategy: Quantum.RunStrategy.Local,
  timezone: "America/New_York"

config(:mcp, Janitor,
  log: [init: false],
  # modules to call at startup (typically to purge cmds or ack orphans)
  at_startup: [{PulseWidthCmd, :purge_cmds}],
  switch_cmds: [
    purge: true,
    interval: {:mins, 2},
    older_than: {:weeks, 1},
    log: false
  ],
  orphan_acks: [interval: {:mins, 1}, older_than: {:mins, 1}, log: true]
)

config :mcp, MessageSave,
  log: [init: false],
  save: true,
  purge: [all_at_startup: true, older_than: [minutes: 3], log: false]

config :mcp, Mqtt.InboundMessage,
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
  switch_msgs: {Switch, :external_update},
  remote_msgs: {Remote, :external_update},
  pwm_msgs: {PulseWidth, :external_update}

config :mcp, OTA,
  url: [
    host: "www.wisslanding.com",
    uri: "janice/mcr_esp/firmware",
    fw_file: "latest-mcr_esp.bin"
  ]

config :mcp, PulseWidthCmd,
  log: [cmd_ack: false],
  # the acked_before and sent_before lists are passed to Timex
  # to created a shifted Timex.DateTime in UTC
  purge: [acked_before: [days: 1]],
  orphan: [sent_before: [seconds: 3], log: false]

import_config "#{Mix.env()}.exs"
