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

# configure erlang's lager (used by emqttc)
config :lager,
  handlers: [
    lager_console_backend: :error,
    lager_file_backend: [file: 'var/log/error.log', level: :error, size: 4096, count: 2]
  ],
  error_logger_redirect: false,
  error_logger_whitelist: [Logger.ErrorHandler],
  crash_log: false

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

# config :mcp, build_env, "#{Mix.env}"
# config :mcp, namespace: Web
# config :mcp, :generators, context_app: false

# Configures the endpoint
config :mcp, Web.Endpoint,
  # url: [host: "localhost", path: "/janice"],
  url: [host: "localhost"],
  # good enough for development and test
  # real secret_key is set in prod.secrets.exs
  secret_key_base: "F+nBtFWds844L6U1OrfNhZcui+qPsPZYB6E5GM1H1skAdb14Jnmp14nLUKYNjmbH",
  render_errors: [view: Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Web.PubSub, pool_size: 1, adapter: Phoenix.PubSub.PG2]

config :mcp, Mqtt.InboundMessage,
  log_reading: false,
  temperature_msgs: {Sensor, :external_update},
  switch_msgs: {Switch, :external_update},
  startup_msgs: {Remote, :external_update}

config :ueberauth, Ueberauth, base_path: "/janice/auth"

# configured here for reference, actual secrets set in prod.secret.exs
config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: "** set in prod.secret.exs",
  client_secret: "** set in prod.secret.exs"

config :mcp, Web.Guardian,
  issuer: "Janice",
  ttl: {30, :days},
  verify_issuer: true,
  # good enough for dev and test, real secret_key is set in prod.secrets.exs
  secret_key: "MkzoSH0QNUpYmlP7VA4wOZiflSu1g0Xz3CElTiQCwQUUYCtYBudr9hAAa5nWJl55"

config :mcp, Web.VerifySessionPipeline,
  module: Web.Guardian,
  error_handler: Web.AuthErrorHandler

config :mcp, Web.AuthAccessPipeline,
  module: Web.Guardian,
  error_handler: Web.AuthErrorHandler

config :mcp, Web.ApiAuthAccessPipeline,
  module: Web.Guardian,
  error_handler: Web.ApiAuthErrorHandler

config :phoenix, :format_encoders, json: Jason

import_config "#{Mix.env()}.exs"
