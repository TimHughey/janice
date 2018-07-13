defmodule SwitchGroupTest do
  @moduledoc false

  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  import JanTest
  use Timex

  setup do
    :ok
  end

  @moduletag :switch_group
  setup_all do
    new_sws = [70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83]

    for s <- new_sws, do: create_switch(s, 8, false)

    :ok
  end

  test "can create (add) a switch group" do
    name = "test sw grp 01"

    nsg = %SwitchGroup{
      name: name,
      members: ["ds/switch070:0", "ds/switch070:1", "ds/switch070:2"]
    }

    {rc, sg} = SwitchGroup.add(nsg)

    assert rc === :ok
    assert sg.name === name
  end

  test "can get the state of a SwitchGroup" do
    name = "test sw grp 02"

    nsg = %SwitchGroup{
      name: name,
      members: ["ds/switch071:0", "ds/switch071:1", "ds/switch071:2"]
    }

    {rc, _sg} = SwitchGroup.add(nsg)

    state = SwitchGroup.state(name)

    assert rc === :ok
    assert state === false
  end

  test "can set the state of a SwitchGroup" do
    name = "test sw grp 03"

    nsg = %SwitchGroup{
      name: name,
      members: ["ds/switch072:0", "ds/switch072:1", "ds/switch072:2"]
    }

    {rc, _sg} = SwitchGroup.add(nsg)

    state = SwitchGroup.state(name, position: true)

    assert rc === :ok
    assert state === true
  end

  test "can detect missing members in new SwitchGroup" do
    nsg = %SwitchGroup{
      name: "bad members",
      members: ["bad1", "bad2"]
    }

    {rc, sg} = SwitchGroup.add(nsg)

    assert rc === :bad_members
    assert is_nil(sg)
  end
end
