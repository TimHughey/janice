defmodule McpTest do
  use ExUnit.Case
  doctest Mcp

  test "greets the world" do
    assert Mcp.hello() == :world
  end
end
