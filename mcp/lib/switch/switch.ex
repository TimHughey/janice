defmodule Switch do
  @moduledoc ~S"""
  Switch

  Primary entry module for all Switch functionality.
  """

  require Logger

  alias Switch.{Alias}

  defmacro __using__([]) do
    quote do
      def sw_position(name, opts \\ [])

      def sw_position(name, opts) when is_list(opts) do
        ensure = Keyword.get(opts, :ensure, false)
        position = Keyword.get(opts, :position, nil)

        if ensure and is_boolean(position) do
          unquote(__MODULE__).position_ensure(name, opts)
        else
          Switch.Alias.position(name, opts)
        end
      end
    end
  end

  #
  ## Private
  #

  def position_ensure(name, opts) do
    pos_wanted = Keyword.get(opts, :position)
    {rc, pos_current} = sw_rc = Alias.position(name)

    with {:switch, :ok} <- {:switch, rc},
         {:ensure, true} <- {:ensure, pos_wanted == pos_current} do
      # position is correct, return it
      sw_rc
    else
      # there was a problem with the switch, return
      {:switch, _error} ->
        sw_rc

      # switch does not match desired position, force it
      {:ensure, false} ->
        # force the position change
        opts = Keyword.put(opts, :lazy, false)
        Alias.position(name, opts)

      error ->
        log_position_ensure(sw_rc, error, name, opts)
    end
  end

  #
  ## Logging
  #

  defp log_position_ensure(sw_rc, error, name, opts) do
    Logger.warn([
      "unhandled position_ensure() condition\n",
      "name: ",
      inspect(name, pretty: true),
      "\n",
      "opts: ",
      inspect(opts, pretty: true),
      "\n",
      "error: ",
      inspect(error, pretty: true)
    ])

    sw_rc
  end
end
