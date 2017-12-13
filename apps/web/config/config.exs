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

config :ueberauth, Ueberauth,
  base_path: "/mercurial/auth"

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("MERC_GITHUB_CLIENT_ID"),
  client_secret: System.get_env("MERC_GITHUB_CLIENT_SECRET")

config :web, Web.Guardian,
  allowed_algos: ["ES512"],
  issuer: "Mercurial",
  ttl: {30, :days},
  verify_issuer: true,
  secret_key: %{
    "crv" => "P-521",
    "d" => "axDuTtGavPjnhlfnYAwkHa4qyfz2fdseppXEzmKpQyY0xd3bGpYLEF4ognDpRJm5IRaM31Id2NfEtDFw4iTbDSE",
    "kty" => "EC",
    "x" => "AL0H8OvP5NuboUoj8Pb3zpBcDyEJN907wMxrCy7H2062i3IRPF5NQ546jIJU3uQX5KN2QB_Cq6R_SUqyVZSNpIfC",
    "y" => "ALdxLuo6oKLoQ-xLSkShv_TA0di97I9V92sg1MKFava5hKGST1EKiVQnZMrN3HO8LtLT78SNTgwJSQHAXIUaA-lV"
  }

config :web, Web.VerifySessionPipeline,
  module: Web.Guardian,
  error_handler: Web.AuthErrorHandler

config :web, Web.AuthAccessPipeline,
  module: Web.Guardian,
  error_handler: Web.AuthErrorHandler

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
