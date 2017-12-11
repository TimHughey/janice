# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :web,
  namespace: Web,
  ecto_repos: [Mcp.Repo]

# Configures the endpoint
config :web, Web.Endpoint,
  #url: [host: "localhost", path: "/mercurial"],
  url: [host: "localhost"],
  secret_key_base: "F+nBtFWds844L6U1OrfNhZcui+qPsPZYB6E5GM1H1skAdb14Jnmp14nLUKYNjmbH",
  render_errors: [view: Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Web.PubSub,
           pool_size: 1,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :web, :generators,
  context_app: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
