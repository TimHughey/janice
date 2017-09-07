# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :dragon,
  namespace: Dragon,
  ecto_repos: [Dragon.Repo]

# Configures the endpoint
config :dragon, DragonWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "fUkS8sOkD4T8ozzUq3T2NwOP2CspQ++LjIePfhlnZgpS8vHQpo74BhdeuH/CJhd5",
  render_errors: [view: DragonWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Dragon.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
