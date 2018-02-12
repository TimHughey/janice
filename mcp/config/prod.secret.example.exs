use Mix.Config

config :mcp, Repo,
  hostname: "obviously the hostname of the rdbms",
  password: "and the password for the account"

# see the install and configure documents for influxdb
config :mcp, Fact.Influx,
  host: "influx db host",
  auth: [method: :basic, username: "user", password: "pass"]

# see the documentation for the MQTT broker that will be used
# if you don't have one yet mosquitto is a good option
# and the config below works with it
config :mcp, Mqtt.Client,
  broker: [
    client_id: "merc-prod",
    clean_session: false,
    username: "user",
    password: "pass",
    # NOTE: charlist for compatibility with erlang emqttc library!
    host: 'hostname.example.com',
    port: 18883
  ]

config :mcp, Web.Guardian, secret_key: "use mix guardian.gen.key to create one"

config :mcp, Web.Endpoint, secret_key_base: "use mix phx.gen.secret to create one"

# visit GitHub's OAuth page to set-up your account to allow for auth
config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: "client id from GitHub",
  client_secret: "client secret from GitHub"
