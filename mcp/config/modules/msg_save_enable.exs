use Mix.Config

config(:mcp, MessageSave,
  log: [init: false],
  save: true,
  purge: [all_at_startup: true, older_than: [minutes: 3], log: false]
)
