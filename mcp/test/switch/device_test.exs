defmodule SwitchDeviceTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Janice.TimeSupport
  alias Switch.Device

  setup do
    :ok
  end

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
      Map.get(context, :device, ["ds/swdev", num_str] |> IO.iodata_to_binary())

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

  @moduletag :switch_device
  setup_all do
    # new_sws = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 99]
    #
    # for s <- new_sws do
    #   create_switch(s, 8, false)
    # end

    :ok
  end

  @tag sd_num: 0
  test "process reading for non-existant switch device", %{r: r} do
    res = Device.upsert(r)

    assert is_map(res)
    assert Map.has_key?(res, :processed)

    %{processed: {rc, sd}} = res

    assert rc == :ok
    assert %Device{} = sd
  end

  @tag sd_num: 1
  @tag insert: true
  test "process reading for existing switch device ", %{
    r: r,
    sd: {_rc, orig_sd}
  } do
    {rc, sd} = Device.upsert(r) |> Map.get(:processed, {:unset, %Device{}})

    assert rc === :ok
    assert %Device{} = orig_sd
    assert %Device{} = sd

    assert Map.get(orig_sd, :discovered_at, false) ==
             Map.get(sd, :discovered_at, true)
  end

  @tag sd_num: 2
  @tag insert: true
  test "can get the state of a pio", %{device: device} do
    {rc, state} = Device.pio_state(device, 1)

    assert rc == :ok
    assert state
  end

  @tag sd_num: 3
  @tag insert: true
  test "can handle request for state of unknown pio", %{device: device} do
    rc = Device.pio_state(device, 10)

    assert rc == {:bad_pio, {device, 10}}
  end

  @tag sd_num: 4
  @tag insert: true
  test "can handle request for state unknown device", %{device: _device} do
    rc = Device.pio_state("foobar", 1)

    assert rc == {:not_found, "foobar"}
  end

  @tag sd_num: 5
  @tag insert: true
  test "can get the pio count of a device", %{device: device} do
    rc = Device.pio_count(device)

    assert rc == 3
  end

  @tag sd_num: 6
  @tag insert: true
  test "can process reading for existing device", %{device: device, r: r} do
    sd1 = Device.find(device)

    r = %{
      r
      | mtime: TimeSupport.unix_now(:second),
        dev_latency_us: 2000,
        states: [
          %{pio: 0, state: true},
          %{pio: 1, state: false},
          %{pio: 2, state: true}
        ]
    }

    r2 = Device.upsert(r)

    assert Map.has_key?(r2, :processed)

    %{processed: {rc, sd2}} = r2

    assert rc == :ok
    assert %Device{} = sd2

    assert Map.get(sd1, :inserted_at) == Map.get(sd2, :inserted_at)
    refute Map.get(sd1, :updated_at) == Map.get(sd2, :updated_at)

    %Device{dev_latency_us: latency} = sd2
    assert latency == 2000

    pio_res = Device.pio_state(device, 1)

    assert pio_res == {:ok, false}
  end

  @tag sd_num: 7
  @tag insert: true
  test "can detect and log invalid changes to a device", %{r: r} do
    r = %{r | mtime: TimeSupport.unix_now(:second), dev_latency_us: -100}

    func = fn ->
      res = Device.upsert(r)
      assert Map.has_key?(res, :processed)

      {rc, _x} = Map.get(res, :processed)
      assert rc == :invalid_changes
    end

    assert capture_log(func) =~ "invalid changes"
  end

  @tag sd_num: 8
  @tag insert: true
  test "can check if a device exists", %{device: device} do
    assert Device.exists?(device, 1)
    refute Device.exists?(device, 4)
    refute Device.exists?("foobar", 0)
  end
end
