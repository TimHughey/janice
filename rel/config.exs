# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :default,
    # This sets the default environment used by `mix release`
    # default_environment: Mix.env()
    default_environment: :prod 

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set dev_mode: true
  set include_erts: false
  set cookie: :"~m5l{}|7BQlj!r_[Q]T(QP,M|e6EbHlQF;?b.h2t{[e,{]w@4nqJ5x2(L~n<?G?f"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"iK0o`UAfI1F_%{eM6E:8p$V$Vwx&,uhVuUr?sQ5pB}_t{Wgn&y60d8s{rhqBwVde"
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :mercurial do
  set version: "0.1.0"
  set applications: [
    :runtime_tools,
    web: :permanent,
    command: :permanent,
    dispatcher: :permanent,
    fact: :permanent,
    mcp: :permanent,
    mqtt: :permanent
  ]
end

