defmodule SwitchCommandTest do
  @moduledoc false

  use Timex
  use ExUnit.Case, async: true

  use JanTest

  # import ExUnit.CaptureLog

  alias Janice.TimeSupport
  alias Switch.{Command, Device}

  setup do
    :ok
  end

  # context @tag inputs:
  #  sd_num:  integer used to create a unique Switch Device (default: 0)
  #  host:    remote mcr host id, (default: mcr.switch_device0x<num>)
  #  name:    remote mcr host name, (default: rem_swdev0x<num>)
  #  device:  switch device name, (default: ds/swdev0x<num>)
  #  insert:  boolean, if true call Device.upsert/1

  setup context do
    num = Map.get(context, :sd_num, 0)
    num_str = ["0x", Integer.to_string(num, 16)] |> IO.iodata_to_binary()

    host =
      Map.get(
        context,
        :host,
        ["mcr.switch_device", num_str] |> IO.iodata_to_binary()
      )

    name =
      Map.get(context, :name, ["rem_swdev", num_str] |> IO.iodata_to_binary())

    device =
      Map.get(
        context,
        :device,
        ["ds/swdev", num_str] |> IO.iodata_to_binary()
      )

    # create a simulated external reading
    r = %{
      processed: false,
      type: "switch",
      host: host,
      name: name,
      hw: "esp32",
      device: device,
      pio_count: 3,
      states: [
        %{pio: 0, state: false},
        %{pio: 1, state: true},
        %{pio: 2, state: false}
      ],
      vsn: "xxxxx",
      ttl_ms: 30_000,
      dev_latency_us: 1000,
      mtime: TimeSupport.unix_now(:second),
      log: false
    }

    sd =
      if Map.get(context, :insert, false),
        do: Device.upsert(r) |> Map.get(:processed),
        else: nil

    # pio = context[:pio]
    # device_pio = if pio, do: device_pio(n, pio), else: device_pio(n, 0)

    {:ok, r: r, host: host, name: name, device: device, sd: sd}
  end

  @moduletag :switch_command
  setup_all do
    :ok
  end

  @tag sd_num: 1
  @tag insert: true
  test "can add a Command to an existing Device", %{
    r: r,
    sd: {_rc, %Device{last_cmd_at: last_cmd_at} = sd}
  } do
    {rc, sd} = Device.add_cmd(sd, "cmd_test", TimeSupport.utc_now())

    assert rc == :ok
    assert %Device{} = sd

    %Device{last_cmd_at: updated_last_cmd_at, states: states} = sd
    assert Timex.after?(updated_last_cmd_at, last_cmd_at)

    sd = Device.reload(sd)

    assert Ecto.assoc_loaded?(sd.cmds)
    assert length(sd.cmds)
    assert is_binary(hd(sd.cmds) |> Map.get(:refid))

    # grab available required keys from the reading (in the context)
    # add required keys and submit to Switch.Device for processing

    # simulate the ack from the mcr device:
    #  1. grab required keys from the reading in the context
    #  2. add remaining required keys
    #  3. create the ack_msg
    #  4. send to Device.upsert/1 for processing
    msg =
      Map.merge(Map.take(r, [:device, :host, :name]), %{
        refid: hd(sd.cmds) |> Map.get(:refid),
        states: states,
        type: "switch"
      })
      |> ack_msg()

    %{processed: {rc, res}} = Device.upsert(msg)

    assert rc == :ok
    assert %Device{} = res
  end

  test "can get list (even if empty) of orphans" do
    list = Command.orphan_list()

    assert is_list(list)
  end

  test "can get Janitor opts specific to Switch.Command" do
    opts = Command.janitor_opts()

    assert is_list(opts)
    assert Keyword.has_key?(opts, :orphan)
  end

  test "can call purge with the dryrun option" do
    {rc, res} = Command.purge(dryrun: true)

    assert :dryrun == rc
    assert is_list(res)
  end

  @tag sd_num: 2
  @tag insert: true
  test "can call purge with the dryrun and older_than options", %{
    r: _r,
    sd: {_rc, %Device{last_cmd_at: _last_cmd_at} = sd}
  } do
    for _x <- 0..30 do
      {elapsed, {rc, _res}} =
        Duration.measure(fn ->
          Device.add_cmd(sd, "cmd_test", TimeSupport.utc_now())
        end)

      assert rc == :ok
      if Duration.to_microseconds(elapsed) < 750, do: Process.sleep(20)
    end

    {rc, res} =
      Command.purge(dryrun: true, older_than: [milliseconds: 10], log: true)

    assert :dryrun == rc
    assert is_list(res)
    assert Enum.count(Keyword.get(res, :trash, 0)) >= 1
  end

  @tag sd_num: 3
  @tag insert: true
  test "can purge commands", %{
    r: _r,
    sd: {_rc, %Device{last_cmd_at: _last_cmd_at} = sd}
  } do
    for _x <- 0..30 do
      {elapsed, {rc, _res}} =
        Duration.measure(fn ->
          Device.add_cmd(sd, "cmd_test", TimeSupport.utc_now())
        end)

      assert rc == :ok
      if Duration.to_microseconds(elapsed) < 750, do: Process.sleep(10)
    end

    {rc, res} = Command.purge(older_than: [seconds: 1, milliseconds: 200])

    assert :purge_queued == rc

    assert is_list(res)
    assert Enum.count(Keyword.get(res, :trash)) >= 1
  end

  @tag sd_num: 4
  @tag insert: true
  test "can get list of orphans (at least one)", %{
    r: _r,
    sd: {_rc, %Device{last_cmd_at: _last_cmd_at} = sd}
  } do
    {rc, sd} = Device.add_cmd(sd, "cmd_test", TimeSupport.utc_now())

    assert rc == :ok
    assert %Device{} = sd

    sd = Device.reload(sd)

    assert Ecto.assoc_loaded?(sd.cmds)
    assert length(sd.cmds)
    assert is_binary(hd(sd.cmds) |> Map.get(:refid))

    Process.sleep(10)

    list = Command.orphan_list(sent_before: [milliseconds: 9])

    assert is_list(list)
    assert length(list) >= 1
  end

  test "the truth will set you free" do
    refute true == false
  end
end
