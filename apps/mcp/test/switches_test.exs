defmodule Mcp.SwitchesTest do
  @moduledoc false
  use ExUnit.Case, async: false
  doctest Mcp.Switches

  alias Mcp.Switches

  setup_all do
    Switches.add(%Switches{friendly_name: "water_pump"})
    :ok
  end

  test "acknowledge a switch command" do
    %{cmd_ref: cmd_ref, pio: _} = Switches.off("water_pump")
    %{cmd_dt: _, uuid: uuid} = cmd_ref
    {acked_uuid, latency} = Switches.ack_cmd("water_pump", uuid)

    assert (acked_uuid === uuid) and (latency > 0)
  end

  test "hande acknowledge with a non-existent uuid" do
    {acked_uuid, latency} = Switches.ack_cmd("water_pump", "bad_uuid")

    assert is_nil(acked_uuid) and (latency == 0)
  end

end
