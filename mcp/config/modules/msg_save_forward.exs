use Mix.Config

config :mcp, MessageSave,
  log: [init: false],
  save: true,
  save_opts: [],
  forward: true,
  forward_opts: [in: [feed: {"dev/mcr/f/report", 0}]],
  purge: [all_at_startup: true, older_than: [minutes: 20], log: true]
