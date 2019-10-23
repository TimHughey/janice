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

config :mcp, OTA,
  url: [
    host: "www.wisslanding.com",
    uri: "janice/mcr_esp/firmware",
    fw_file: "latest-mcr_esp.bin"
  ]

config :mcp, Janice.Scheduler,
  run_strategy: Quantum.RunStrategy.Local,
  timezone: "America/New_York"

config :mcp, Mqtt.InboundMessage,
  additional_message_flags: [
    log_invalid_readings: false,
    log_roundtrip_times: false
  ],
  log_reading: false,
  temperature_msgs: {Sensor, :external_update},
  switch_msgs: {Switch, :external_update},
  remote_msgs: {Remote, :external_update}

import_config "#{Mix.env()}.exs"
