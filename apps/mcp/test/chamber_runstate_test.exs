defmodule ChamberRunStateTest do
  @moduledoc :false

  use ExUnit.Case, async: true

  alias Mcp.Chamber.RunState

  test "can create a Chamber.Runstate?" do
    rs = RunState.create("test")

    assert RunState.name(rs) == "test"
  end

  test "can set Chamber.RunState air stir and detect idle?" do
    rs = RunState.create("test")

    rs = RunState.air_stir(rs, "buzzer")

    rs = RunState.air_stir(rs, :true, :nil)
    :timer.sleep(100)

    rs = RunState.air_stir(rs, :false, :nil)
    :timer.sleep(500)

    assert RunState.air_stir_idle?(rs, 450) == :true
  end

  test "can set Chamber.RunState air stir and detect not idle?" do
    rs = RunState.create("test")

    rs = RunState.air_stir(rs, "buzzer")

    rs = RunState.air_stir(rs, :true, :nil)
    :timer.sleep(100)

    rs = RunState.air_stir(rs, :false, :nil)
    :timer.sleep(400)

    assert RunState.air_stir_idle?(rs, 450) == :false
  end
end
