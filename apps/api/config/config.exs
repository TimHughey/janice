# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :api,
  namespace: Api,
  ecto_repos: [Mcp.Repo]

# Configures the endpoint
config :api, ApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Nr0WqN1rfq3nMe65MT0sHeGdB2Xt4ybhkdeFR52muvHYMV7ULkj2Pw50Qc7vI9MZ",
  render_errors: [view: ApiWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Api.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :api, :generators,
  migration: false,
  model: false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
