use Mix.Config

config :web, Web.Endpoint,
  http: [port: {:system, "PORT"}],
  load_from_system_env: true,
  url: [scheme: "https:", host: "www.wisslanding.com", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json",
  static_url: [path: "/mercurial"],
  server: true,
  # root: ".",
  version: Application.spec(:myapp, :vsn),
  secret_key_base: System.get_env("MERC_SECRET_KEY_BASE")

config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github,
        [default_scope: "user:email"]}]

# Tell phoenix to actually serve endpoints when run as a release
config :phoenix, :serve_endpoints, true

config :logger, backends: [:console], level: :warn

import_config "prod.secret.exs"
