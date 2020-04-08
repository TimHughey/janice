defmodule Config.Helper do
  @moduledoc false

  require Logger

  defmacro __using__(_opts) do
    quote do
      def config(key) when is_atom(key) do
        Application.get_application(__MODULE__)
        |> Application.get_env(__MODULE__, [])
        |> Keyword.get(key, [])
      end

      def log?(opts) when is_list(opts), do: Keyword.get(opts, :log, true)

      def log?(category, default)
          when is_atom(category) and is_boolean(default) do
        Application.get_application(__MODULE__)
        |> Application.get_env(__MODULE__, log: [init_args: false, init: false])
        |> Keyword.get(:log, [])
        |> Keyword.get(category, default)
      end

      # extract :opts from a map (usually a state)
      def log?(%{opts: opts}, category, default \\ true)
          when is_atom(category) and is_boolean(default),
          do: Keyword.get(opts, :log, []) |> Keyword.get(category, default)

      def log_default_opts(opts) do
        log?(:default_opts, false) &&
          Logger.info(["configuration not found, using defaults"])
      end

      def module_opts(default_opts) when is_list(default_opts),
        do:
          Application.get_application(__MODULE__)
          |> Application.get_env(__MODULE__, default_opts)
    end
  end
end
