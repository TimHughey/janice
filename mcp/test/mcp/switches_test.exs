defmodule SwitchTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Timex

  setup_all do
    :ok
  end

  test "process an external switch update" do
    r = %{
      device: "ds/291d1823000000",
      pio_count: 8,
      cmdack: false,
      states: [
        %{pio: 0, state: true},
        %{pio: 1, state: true},
        %{pio: 2, state: true},
        %{pio: 3, state: true},
        %{pio: 4, state: true},
        %{pio: 5, state: true},
        %{pio: 6, state: true},
        %{pio: 7, state: true}
      ],
      mtime: Timex.now() |> Timex.to_unix(),
      latency: 100
    }

    res = Switch.external_update(r)

    assert res === :ok
  end

  # test "process an internal switch update (state change)" do
  #   sw = SwitchState.state("ds/291d1823000000:0", false)
  #
  #   assert %Switch{} = sw
  # end

  test "get all switches preloaded with states" do
    switches = Switch.all(:devices)

    assert is_binary(hd(switches))
  end

  # test "get switch state by friendly name" do
  #   SwitchState.state("led1", false)
  #   state = Switch.get_state("led1")
  #
  #   assert state == false
  # end
  #
  # test "get switch state by unknown friendly name" do
  #   state = Switch.get_state("foobar")
  #
  #   assert state == nil
  # end
  #
  # test "get switch unack'ed commands" do
  #   cmds = Switch.get_unack_cmds("led1")
  #
  #   assert Enum.count(cmds) >= 0
  # end
  #
  # test "get switch unack'ed commands for unknown friendly name" do
  #   cmds = Switch.get_unack_cmds("foobar")
  #   assert [] == cmds
  # end
  #
  # test "process an external switch update with cmdack" do
  #   initial_cmds = Switch.get_unack_cmds("led1")
  #   %SwitchCmd{sent_at: sent_at, refid: refid} = hd(initial_cmds)
  #
  #   r = %{
  #     device: "ds/291d1823000000",
  #     pio_count: 8,
  #     cmdack: true,
  #     refid: refid,
  #     latency: 1000,
  #     msg_recv_dt: Timex.shift(sent_at, seconds: 1),
  #     states: [
  #       %{pio: 0, state: true},
  #       %{pio: 1, state: true},
  #       %{pio: 2, state: true},
  #       %{pio: 3, state: true},
  #       %{pio: 4, state: true},
  #       %{pio: 5, state: true},
  #       %{pio: 6, state: true},
  #       %{pio: 7, state: true}
  #     ]
  #   }
  #
  #   fnames = Switch.external_update(r)
  #
  #   cmds = Switch.get_unack_cmds("led1")
  #
  #   assert Enum.count(cmds) < Enum.count(initial_cmds)
  # end

  doctest Switch
end
