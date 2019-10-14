# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  default_release: :default,
  default_environment: :prod

environment :dev do
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set(dev_mode: false)
  set(include_erts: true)
  set(cookie: :janice)
  set(vm_args: "rel/dev-vm.args")

  set(pre_configure_hooks: "rel/hooks/dev/pre_configure.d")

  set(
    commands: [
      examine_env: "rel/commands/dev/examine_env.sh"
    ]
  )
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"augury-kinship-swain-circus")
  set(vm_args: "rel/prod-vm.args")
  set(run_erl_env: "RUN_ERL_LOG_MAXSIZE=10000000 RUN_ERL_LOG_GENERATIONS=10")
  set(pre_configure_hooks: "rel/hooks/pre_configure")
end

environment :standby do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"augury-kinship-swain-circus")
  set(vm_args: "rel/standby-vm.args")
  set(run_erl_env: "RUN_ERL_LOG_MAXSIZE=10000000 RUN_ERL_LOG_GENERATIONS=10")
  set(pre_configure_hooks: "rel/hooks/pre_configure")
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :mcp do
  set(version: current_version(:mcp))

  set(
    applications: [
      :runtime_tools
    ]
  )
end
