# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

config :distillery, no_warn_missing: [:distillery]

config :logger,
  backends: [:console],
  level: :info

config :logger, :console,
  metadata: [:module],
  format: "$time $metadata$message\n"
