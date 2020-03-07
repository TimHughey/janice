use Mix.Config
@moduledoc false

cconfig(:mcp, MessageSave,
  log: [init: false],
  save: false,
  purge: [all_at_startup: true, older_than: [minutes: 3], log: false]
)
