# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mqtt, Mqtt.Client,
  broker: [client_id: "mercurial-test", clean_session: 0,
           username: "mqtt", password: "mqtt",
           host: "jophiel.wisslanding.com", port: 1883, ssl: false],
  feeds: [topics: ["test/mcr/f/report"], qoses: [0]],
  rpt_feed: "test/mcr/f/report",
  cmd_feed: "test/mcr/f/command"
