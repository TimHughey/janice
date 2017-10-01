use Mix.Config

config :mcp, Mercurial.MQTTClient,
  broker: [client_id: "merc-client", host: "jophiel.wisslanding.com", port: 1883, username: "mqtt", password: "mqtt"],
  cmd_feed: "/dev/f/sensor"
