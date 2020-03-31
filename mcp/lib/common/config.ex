defmodule Config.Helper do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def config(key) when is_atom(key) do
        Application.get_application(__MODULE__)
        |> Application.get_env(__MODULE__)
        |> Keyword.get(key, [])
      end

      def log?(opts) when is_list(opts), do: Keyword.get(opts, :log, true)

      def log?(category, default)
          when is_atom(category) and is_boolean(default) do
        Application.get_application(__MODULE__)
        |> Application.get_env(__MODULE__)
        |> Keyword.get(:log, [])
        |> Keyword.get(category, default)
      end

      # extract :opts from a map (usually a state)
      def log?(%{opts: opts}, category, default \\ true)
          when is_atom(category) and is_boolean(default),
          do: Keyword.get(opts, :log, []) |> Keyword.get(category, default)
    end
  end
end
