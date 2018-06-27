defmodule SwitchStateTest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import JanTest
  use Timex

  setup do
    :ok
  end

  setup context do
    n = if context[:num], do: context[:num], else: 0

    pio = context[:pio]
    device_pio = if pio, do: device_pio(n, pio), else: device_pio(n, 0)

    [num: n, device_pio: device_pio]
  end

  @moduletag :switch
  setup_all do
    new_sws = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 99]

    for s <- new_sws do
      create_switch(s, 8, false)
    end

    :ok
  end

  @tag num: 98
  test "process well formed external switch update", context do
    res = create_switch(context[:num], 8, false)

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: host("switch", 1), log: false}
    msg = capture_log(fn -> Switch.external_update(eu) end)

    assert msg =~ "bad map"
  end

  @tag num: 0
  test "process two external updates for the same switch", context do
    n = context[:num]
    rc1 = create_switch(n, 8, false)
    rc2 = create_switch(n, 8, true)

    assert rc1 === :ok and rc2 === :ok
  end

  @tag num: 1
  test "change the name of a switch state", context do
    n = context[:num]

    asis = device_pio(n, 0)
    tobe = name("switch", n)
    {rc, ss} = SwitchState.change_name(asis, tobe, "changed via test")

    assert(rc === :ok and ss.name === tobe)
  end

  @tag num: 2
  test "change switch position and handle not found", context do
    n = context[:num]

    dev = device_pio(n, 0)
    pos = SwitchState.state(dev, position: true)

    msg = capture_log(fn -> SwitchState.state("foobar", position: true) end)

    assert pos
    assert msg =~ "foobar not found while SETTING state"
  end

  @tag num: 3
  test "change switch position lazy", context do
    n = context[:num]

    lazy1 = SwitchState.state(device_pio(n, 2), position: false, lazy: true)
    lazy2 = SwitchState.state(device_pio(n, 2), position: true, lazy: true)

    refute lazy1
    assert lazy2
  end

  @tag num: 4
  test "record a cmd and ack", context do
    n = context[:num]

    dev = device_pio(n, 0)

    ss = SwitchState.get_by(name: dev)

    {rc, refid} = SwitchCmd.record_cmd(dev, ss, ack: false, log: false)

    ack = SwitchCmd.is_acked?(refid)

    assert rc === :ok and ack
  end

  test "ack a refid that doesn't exist" do
    msg = capture_log(fn -> SwitchCmd.ack_now("0000", log: false) end)

    assert msg =~ "won't ack"
  end

  @tag num: 5
  @tag pio: 0
  test "check for pending commands", context do
    ss = context[:device_pio]
    SwitchState.state(ss, position: false)

    :timer.sleep(10)

    pending = Switch.pending_cmds(ss, milliseconds: -10)

    assert pending >= 1
  end

  test "get all SwitchState (names and everything)" do
    names = SwitchState.all(:names)
    everything = SwitchState.all(:everything)
    is_struct = if not Enum.empty?(everything), do: %SwitchState{} = hd(everything), else: false

    refute Enum.empty?(names)
    refute Enum.empty?(everything)
    assert is_binary(hd(names))
    assert is_struct
  end

  test "handle bad args SwitchState.state() and SwitchState.get_by()" do
    msg1 = capture_log(fn -> SwitchState.state(nil) end)
    msg2 = capture_log(fn -> SwitchState.get_by("foobar") end)
    msg3 = capture_log(fn -> SwitchState.get_by(foo: "bar") end)

    assert msg1 =~ "nil"
    assert msg2 =~ "bad args:"
    assert msg3 =~ "get_by bad args:"
  end

  @tag num: 6
  test "toggle a switch", context do
    n = context[:num]

    ss = SwitchState.get_by(name: device_pio(n, 1))
    before_toggle = ss.state

    after_toggle = SwitchState.toggle(ss.id)

    refute before_toggle == after_toggle
  end

  @tag num: 7
  @tag pio: 3
  test "get a SwitchState state (position) by name and handle not found", context do
    ss = SwitchState.state(context[:device_pio])
    msg = capture_log(fn -> SwitchState.state("foobar") end)

    refute ss
    assert msg =~ "foobar not found while RETRIEVING state"
  end

  test "change a SwitchState name and test not found" do
    ss1 = SwitchState.get_by(name: device_pio(0, 4))
    ss2 = SwitchState.get_by(name: device_pio(0, 5))
    {rc1, new_ss} = SwitchState.change_name(ss1.id, name("switch", 4), "changed by test")
    is_ss = %SwitchState{} = new_ss

    {rc2, _} = SwitchState.change_name(ss2.name, name("switch", 5))

    msg =
      capture_log(fn ->
        SwitchState.change_name(1_000_000, name("switch", 6), "changed by test")
      end)

    {rc3, _} = SwitchState.change_name(device_pio(0, 6), name("switch", 5))

    assert rc1 === :ok
    assert is_ss
    assert rc2 == :ok
    assert msg =~ "change name failed"
    assert rc3 == :error
  end

  test "can instantiate a SwitchState" do
    ss = %SwitchState{name: "foobar"}
    assert ss
  end

  test "create a map of states from a list" do
    everything = SwitchState.all(:everything)

    maps = SwitchState.as_list_of_maps(everything)
    first = if Enum.empty?(maps), do: %{}, else: hd(maps)

    refute Enum.empty?(maps)
    assert Map.has_key?(first, :pio)
    assert Map.has_key?(first, :state)
  end

  @tag num: 8
  test "delete a Switch", context do
    n = context[:num]

    sw1 = Switch.get_by(device: device("switch", n))
    {count, sw_rc} = Switch.delete(sw1.id)

    assert count == 1
    assert is_nil(sw_rc)
  end
end
