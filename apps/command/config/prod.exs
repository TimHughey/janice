# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :command, Command.Application,
  build_env: "#{Mix.env}"

config :command, Command.Control,
  startup_delay_ms: 200,
  periodic_timesync_ms: (5 * 60 * 1000),
  rpt_feed: "mcr/f/report",
  cmd_feed: "mcr/f/command",
  build_env: "#{Mix.env}"
