use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :web, Web.Endpoint,
  http: [port: 4001],
  server: false

config :ueberauth, Ueberauth,
  providers: [
    identity: {Ueberauth.Strategy.Identity, [
        callback_methods: ["POST"],
        callback_path: "/mercurial/auth/identity/callback",
        uid_field: :username,
        nickname_field: :username,
      ]}
  ]
