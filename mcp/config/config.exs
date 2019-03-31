# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# external app configuration
config :distillery, no_warn_missing: [:distillery]

# Configures Elixir's Logger
config :logger,
  console: [metadata: [:module], format: "$time $metadata$message\n"],
  backends: [:console],
  level: :info

config :scribe, style: Scribe.Style.Psql

# configure erlang's lager (used by emqttc)
# config :lager,
#   handlers: [
#     lager_console_backend: :error,
#     lager_file_backend: [file: 'var/log/error.log', level: :error, size: 4096, count: 2]
#   ],
#   error_logger_redirect: false,
#   error_logger_whitelist: [Logger.ErrorHandler],
#   crash_log: false

# General application configuration
config :mcp,
  ecto_repos: [Repo],
  build_env: "#{Mix.env()}",
  namespace: Web,
  generators: [context_app: false],
  # default settings for dev and test, must override in prod
  feeds: [
    cmd: {"dev/mcr/f/command", :qos0},
    rpt: {"dev/mcr/f/report", :qos0},
    ota: {"prod/mcr/f/ota", :qos0}
  ]

config :mcp, OTA, firmware_files: [current: "mcr_esp.bin", previous: "mcr_esp.bin.prev"]

config :mcp, Janice.Scheduler,
  run_strategy: Quantum.RunStrategy.Local,
  timezone: "America/New_York"

config :mcp, Mqtt.InboundMessage,
  log_reading: false,
  temperature_msgs: {Sensor, :external_update},
  switch_msgs: {Switch, :external_update},
  remote_msgs: {Remote, :external_update}

import_config "#{Mix.env()}.exs"
