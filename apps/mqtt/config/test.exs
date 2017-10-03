# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :distillery, no_warn_missing: [:elixir_make, :distillery]

config :mqtt, Mqtt.Application,
  build_env: "#{Mix.env}"

config :mqtt, Mqtt.Client,
  broker: [client_id: "mercurial-dev", clean_session: 0,
           username: "mqtt", password: "mqtt",
           host: "jophiel.wisslanding.com", port: 1883, ssl: false],
  feeds: [topics: ["mcr/f/report"], qoses: [0]],
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command",
  build_env: "#{Mix.env}"

config :mqtt, Mqtt.Dispatcher,
  log_reading: true,
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command"

config :logger,
  backends: [:console],
  level: :info

config :logger, :console,
  metadata: [:module],
  format: "$time $metadata$message\n"
