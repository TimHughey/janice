defmodule DutycycleTest do
  use ExUnit.Case

  test "does Dutycycle know of at least one dutycycle?" do
    known = Mcp.Dutycycle.known_cycles()

    assert Enum.count(known) > 0
  end
end
