defmodule Mercurial.Foo.IExHelpers do
  def foo_env do
    Application.get_env(:foo, Mercurial.Foo)
  end

  def config(key) when is_atom(key) do
    Application.get_env(:foo, Mercurial.Foo) |>
      Keyword.get(key)
  end
end
