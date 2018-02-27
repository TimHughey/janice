defmodule SwitchStateTest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.01020304050" <> Integer.to_string(num)
  def name(num), do: "test_name" <> Integer.to_string(num)

  def device(num), do: ("ds/01020340506" <> Integer.to_string(num)) |> String.pad_leading(3, "0")
  def device_pio(num, pio), do: device(num) <> ":#{pio}"

  def pios(num, pos), do: for(n <- 0..(num - 1), do: %{pio: n, state: pos})

  def ext(num, num_pios, pos),
    do: %{
      host: host(num),
      name: name(num),
      hw: "esp32",
      device: device(num),
      pio_count: num_pios,
      states: pios(8, pos),
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def common_ext_update do
    ext(0, 8, false) |> Switch.external_update()
  end

  setup do
    :ok
  end

  setup_all do
    Switch.delete_all(:dangerous)
    :ok
  end

  test "process well formed external switch update" do
    res = ext(0, 8, false) |> Switch.external_update()

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: host(1), log: false}
    msg = capture_log(fn -> Switch.external_update(eu) end)

    assert msg =~ "bad map"
  end

  test "process two external updates for the same switch" do
    rc1 = ext(0, 8, false) |> Switch.external_update()
    rc2 = ext(0, 8, true) |> Switch.external_update()

    assert rc1 === :ok and rc2 === :ok
  end

  test "change the name of a switch state" do
    ext(1, 8, true) |> Switch.external_update()
    asis = device_pio(1, 0)
    tobe = name(1)
    {rc, ss} = SwitchState.change_name(asis, tobe, "changed via test")

    assert(rc === :ok and ss.name === tobe)
  end

  test "change switch position and handle not found" do
    ext(2, 8, true) |> Switch.external_update()
    dev = device_pio(2, 0)
    pos = SwitchState.state(dev, position: true)

    msg = capture_log(fn -> SwitchState.state("foobar", position: true) end)

    assert pos
    assert msg =~ "foobar not found while SETTING state"
  end

  test "change switch position lazy" do
    common_ext_update()

    lazy1 = SwitchState.state(device_pio(0, 2), position: false, lazy: true)
    lazy2 = SwitchState.state(device_pio(0, 2), position: true, lazy: true)

    refute lazy1
    assert lazy2
  end

  test "record a cmd and ack" do
    ext(3, 8, true) |> Switch.external_update()
    dev = device_pio(3, 0)

    ss = SwitchState.get_by_name(dev)

    {rc, refid} = SwitchCmd.record_cmd(dev, ss, ack: false, log: false)

    ack = SwitchCmd.is_acked?(refid)

    assert rc === :ok and ack
  end

  test "ack a refid that doesn't exist" do
    msg = capture_log(fn -> SwitchCmd.ack_now("0000", log: false) end)

    assert msg =~ "won't ack"
  end

  test "check for pending commands" do
    ext(4, 8, true) |> Switch.external_update()
    ss = device_pio(4, 0)
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

    assert msg1 =~ "received nil"
    assert msg2 =~ "bad args:"
    assert msg3 =~ "get_by bad args:"
  end

  test "toggle a switch" do
    common_ext_update()
    ss = SwitchState.get_by(name: device_pio(0, 1))
    before_toggle = ss.state

    after_toggle = SwitchState.toggle(ss.id)

    refute before_toggle == after_toggle
  end

  test "get a SwitchState state (position) by name and handle not found" do
    common_ext_update()
    ss = SwitchState.state(device_pio(0, 3))
    msg = capture_log(fn -> SwitchState.state("foobar") end)

    refute ss
    assert msg =~ "foobar not found while RETRIEVING state"
  end

  test "change a SwitchState name and test not found" do
    common_ext_update()

    ss1 = SwitchState.get_by(name: device_pio(0, 4))
    ss2 = SwitchState.get_by(name: device_pio(0, 5))
    {rc1, new_ss} = SwitchState.change_name(ss1.id, name(4), "changed by test")
    is_ss = %SwitchState{} = new_ss

    {rc2, _} = SwitchState.change_name(ss2.name, name(5))

    msg = capture_log(fn -> SwitchState.change_name(1_000_000, name(6), "changed by test") end)

    {rc3, _} = SwitchState.change_name(device_pio(0, 6), name(5))

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

  test "delete a Switch" do
    ext(9, 8, false) |> Switch.external_update()
    sw1 = Switch.get_by(device: device(9))
    {count, sw_rc} = Switch.delete(sw1.id)

    common_ext_update()
    sw2 = Switch.get_by(device: device(0))

    {count_name, sw2_rc} = Switch.delete(sw2.device)

    assert count == 1
    assert is_nil(sw_rc)
    assert count_name == 1
    assert is_nil(sw2_rc)
  end
end
