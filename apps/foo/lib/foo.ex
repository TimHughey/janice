defmodule Mercurial.Foo do
  @moduledoc """
  Documentation for Foo.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Foo.hello
      :world

  """
  def hello do
    :world
  end

  def config(key) when is_atom(key) do
    opts = Application.get_env(:foo, __MODULE__)

    Keyword.get(opts, key)
  end

end
