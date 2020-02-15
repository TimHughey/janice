defmodule SwitchStateTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import JanTest

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

  def load_ss(opts) when is_list(opts), do: Repo.get_by(SwitchState, opts)

  def load_sw(opts) when is_list(opts),
    do: Repo.get_by(Switch, opts) |> Repo.preload([:states])

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

  @tag num: 2
  test "change switch position and handle not found", context do
    n = context[:num]

    dev = device_pio(n, 0)
    pos = SwitchState.position(dev, position: true)

    msg =
      capture_log(fn ->
        SwitchState.position("foobar", position: true, log: true)
      end)

    assert pos
    assert msg =~ "not found"
  end

  @tag num: 3
  test "change switch position lazy", context do
    n = context[:num]

    lazy1 = SwitchState.position(device_pio(n, 2), position: true, lazy: false)
    lazy2 = SwitchState.position(device_pio(n, 2), position: false, lazy: false)

    assert {:ok, true} == lazy1
    assert {:ok, false} == lazy2
  end

  @tag num: 4
  test "record a cmd and ack", context do
    n = context[:num]

    dev = device_pio(n, 0)

    ss = load_ss(name: dev)

    res =
      SwitchCmd.record_cmd(ss,
        switch_state: ss,
        ack: false,
        log: false,
        record_cmd: true
      )

    ss = Keyword.get(res, :switch_state)
    refid = Keyword.get(res, :refid)

    ack = SwitchCmd.is_acked?(refid)

    assert %SwitchState{} = ss
    assert ack
  end

  test "ack a refid that doesn't exist" do
    msg = capture_log(fn -> SwitchCmd.ack_now("0000", log: false) end)

    assert msg =~ "won't ack"
  end

  @tag num: 5
  @tag pio: 0
  test "check for pending commands", context do
    ss = context[:device_pio]
    SwitchState.position(ss, position: false)

    :timer.sleep(10)

    pending = Switch.pending_cmds(ss, milliseconds: -10)

    assert pending >= 1
  end

  test "get all SwitchState (names and everything)" do
    names = SwitchState.all(:names)
    everything = SwitchState.all(:everything)

    is_struct =
      if Enum.empty?(everything),
        do: false,
        else: %SwitchState{} = hd(everything)

    refute Enum.empty?(names)
    refute Enum.empty?(everything)
    assert is_binary(hd(names))
    assert is_struct
  end

  @tag num: 6
  @tag pio: 2
  test "toggle a switch (by name)", context do
    n = context[:num]
    pio = context[:pio]

    ss = load_ss(name: device_pio(n, pio))
    before_toggle = ss.state

    after_toggle = SwitchState.toggle(device_pio(n, pio))

    refute before_toggle == after_toggle
  end

  @tag num: 6
  @tag pio: 3
  test "can get and set the position of an inverted switch", context do
    n = context[:num]
    pio = context[:pio]

    %SwitchState{name: name, invert_state: initial_inverted} =
      load_ss(name: device_pio(n, pio))

    {rc1, name_rc, opts} = SwitchState.invert_position(name, true)

    {rc2, inverted_pos} =
      SwitchState.position(name, position: true, lazy: false)

    # disabe inverted position
    SwitchState.invert_position(name, false)

    # get the position which should be false with inverted disabled
    {rc3, std_pos} = SwitchState.position(name)

    assert initial_inverted == false
    assert rc1 == :ok
    assert name_rc === name
    assert is_map(opts)
    assert rc2 == :ok
    assert inverted_pos == true
    assert rc3 == :ok
    assert std_pos == false
  end

  @tag num: 6
  @tag pio: 4
  test "can make updates to a SwitchState", context do
    n = context[:num]
    pio = context[:pio]

    %SwitchState{name: name, ttl_ms: ttl_ms} = load_ss(name: device_pio(n, pio))

    {rc1, update_rc, opts} = SwitchState.update(name, ttl_ms: 1000)

    assert rc1 == :ok
    assert update_rc === name
    assert is_map(opts)
    assert Map.has_key?(opts, :ttl_ms)
    assert ttl_ms != Map.get(opts, :ttl_ms)
  end

  @tag num: 7
  @tag pio: 3
  test "get a SwitchState position by name and handle not found",
       context do
    pos = SwitchState.position(context[:device_pio])
    msg = capture_log(fn -> SwitchState.position("foobar", log: true) end)

    assert {:ok, false} == pos
    assert msg =~ "not found"
  end

  @tag num: 7
  @tag pio: 4
  test "can replace a switch", context do
    old_name = device_pio(context[:num], context[:pio])
    new_name = device_pio(context[:num], context[:pio] + 1)

    {rc, name, opts} = SwitchState.replace(old_name, new_name)

    assert :ok == rc
    assert name === old_name
    assert is_list(opts)
  end

  test "can detect SwitchState not found" do
    name = "foobar"
    {rc, not_found_name} = SwitchState.update(name, name: "foobar2")

    assert rc === :not_found
    assert not_found_name == name
  end

  test "can instantiate a SwitchState" do
    ss = %SwitchState{name: "foobar"}
    assert ss
  end

  @tag num: 8
  test "delete a Switch", context do
    n = context[:num]

    sw1 = load_sw(device: device("switch", n))
    {count, sw_rc} = Switch.delete(sw1.id)

    assert count == 1
    assert is_nil(sw_rc)
  end
end
