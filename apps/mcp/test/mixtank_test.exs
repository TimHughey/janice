defmodule MixtankTest do
  use ExUnit.Case

  test "are there any mixtanks?" do
    mixtanks = Mcp.Mixtank.known_tanks()

    assert Enum.count(mixtanks) > 0
  end
end
