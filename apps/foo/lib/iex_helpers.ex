defmodule Mercurial.Foo.IExHelpers do
  def foo_env do
    Application.get_env(:foo, Mercurial.Foo)
  end
end
