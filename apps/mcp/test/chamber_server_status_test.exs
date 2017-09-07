defmodule Mcp.Chamber.ServerStateTest do
  use ExUnit.Case, async: true

  alias Mcp.Chamber.ServerState

  @known1 ["chamber1", "chamber2", "chamber3"]
#  @known2 ["chamber1", "chamber2", "chamber3", "chamber4"]
  @known3 ["chamber1", "chamber2", "chamber4"]
  @known3 ["chamber1", "chamber2", "chamber4", "chamber5"]
  defp setup_known_chambers(kc) do
    %ServerState{} |> ServerState.known_chambers(kc)
  end

  test "can set known chambers in Chamber.ServerState?" do
    kc = @known1
    s = setup_known_chambers(kc)

    assert Enum.count(kc) == Enum.count(ServerState.known_chambers(s))
  end

  test "can set known chambers with same list?" do
    kc1 = @known1

    s = setup_known_chambers(kc1)
    a = ServerState.known_chambers(s)

    s = ServerState.known_chambers(s, kc1)
    b = ServerState.known_chambers(s)

    assert a -- b == []
  end

  test "can set then change known chambers?" do
    s = setup_known_chambers(@known1)

    s = ServerState.known_chambers(s, @known3)

    assert @known3 -- ServerState.known_chambers(s) == []
  end
end
