defmodule RemoteTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  alias Janice.TimeSupport

  def host(num), do: "mcr.remote" <> String.pad_leading(Integer.to_string(num), 3, "0")
  def name(num), do: "remote" <> String.pad_leading(Integer.to_string(num), 3, "0")

  def ext(num),
    do: %{
      host: host(num),
      type: "remote_runtime",
      mtime: TimeSupport.unix_now(:seconds),
      async: false
    }

  def runtime(m) do
    runtime_map = %{
      type: "remote_runtime",
      batt_mv: 3800,
      bssid: "11:22:33:44:55:66",
      ap_rssi: -45,
      ap_pri_chan: 6,
      heap_min: 100 * 1024,
      heap_free: 101 * 1024,
      uptime_ms: 15000
    }

    Map.merge(m, runtime_map)
  end

  def boot(m) do
    boot_map = %{
      type: "boot",
      hw: "esp32",
      vsn: "12345678",
      proj: "mcr",
      idf: "idf-3.3",
      sha: "0123456789abcdef",
      bdate: "04-16-2019",
      btime: "14:01:02",
      mword: "0x123456",
      svsn: 813,
      reset_reason: "software reset"
    }

    Map.merge(m, boot_map)
  end

  setup_all do
    ext(99) |> Map.put(:log, false) |> boot() |> Remote.external_update()
    :ok
  end

  test "process well formed external remote update" do
    res = ext(1) |> runtime() |> Remote.external_update()

    assert res === :ok
  end

  test "process external update of type 'boot'" do
    eu = ext(16)

    initial_mtime = Map.get(eu, :mtime)
    later_mtime = Map.get(eu, :mtime) + 30

    res =
      eu
      |> boot()
      |> Map.merge(%{mtime: later_mtime, log: false})
      |> Remote.external_update()

    rem = Remote.get_by(host: host(16))

    assert res === :ok
    assert Timex.to_unix(rem.last_start_at) >= initial_mtime
  end

  test "can create a changeset from an external update" do
    eu = ext(1) |> boot() |> Map.put(:reset_reason, "test")
    rem = Remote.get_by(host: host(1))

    cs = Remote.changeset(rem, eu)

    assert cs.valid? === true
  end

  test "process external update of type 'remote_runtime'" do
    res = ext(17) |> Map.put_new(:type, "remote_runtime") |> Remote.external_update()

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    fun = fn -> %{host: host(1), type: "boot"} |> Remote.external_update() end
    msg = capture_log(fun)

    # assert msg =~ host(1)
    assert msg =~ "unknown" or msg =~ "bad map"
  end

  test "external update logs remote startup message" do
    fun = fn -> Map.put(ext(4), :log, true) |> boot() |> Remote.external_update() end
    msg = capture_log(fun)

    assert msg =~ name(4)
    assert msg =~ "BOOT"
  end

  test "mark as seen (default threshold)" do
    ext(6) |> Remote.external_update()
    before_mark = Remote.get_by(host: host(6))

    Remote.mark_as_seen(host(1), TimeSupport.unix_now(:seconds))

    after_mark = Remote.get_by(host: host(6))

    assert before_mark.last_seen_at === after_mark.last_seen_at
  end

  @tag long_running: true
  test "mark as seen (zero threshold)" do
    ext(5) |> Remote.external_update()
    before_mark = Remote.get_by(host: host(5))
    :timer.sleep(1001)
    Remote.mark_as_seen(host(5), TimeSupport.unix_now(:seconds), 0)
    after_mark = Remote.get_by(host: host(5))

    assert Timex.compare(after_mark.last_seen_at, before_mark.last_seen_at) == 1
  end

  test "change a name" do
    ext(2) |> Remote.external_update()

    res = Remote.change_name(host(2), name(2))
    %Remote{name: name} = Remote.get_by(name: name(2))

    assert res === :ok and name === name(2)
  end

  test "change a name (name in use)" do
    ext(1) |> Remote.external_update()

    Remote.change_name(host(1), name(1))
    res = Remote.change_name(host(2), name(1))

    assert res === :name_in_use
  end

  test "change a name (by id)" do
    n = 13
    ext(n) |> Remote.external_update()
    r = Remote.get_by(host: host(n))
    res = Remote.change_name(r.id, name(n))

    assert res === name(n)
  end

  test "get_by(name: name)" do
    ext(3) |> Remote.external_update()

    Remote.change_name(host(3), name(3))
    %Remote{name: name} = Remote.get_by(name: name(3))

    assert name === name(3)
  end

  test "get_by(name: name, only: [:last_seen_at, :last_start_at])" do
    ext(3) |> Remote.external_update()
    result = Remote.get_by(host: host(3), only: [:last_seen_at, :last_start_at])

    seen = if is_map(result), do: Map.get(result, :last_seen_at, nil), else: result
    start = if is_map(result), do: Map.get(result, :last_start_at, nil), else: result

    refute is_nil(seen) and is_nil(start)
  end

  test "get_by(name: name, only: :last_seen_at)" do
    ext(3) |> Remote.external_update()
    result = Remote.get_by(host: host(3), only: :last_seen_at)

    last = if is_map(result), do: Map.get(result, :last_seen_at, nil), else: result

    refute is_nil(last)
  end

  test "get_by(id: id)" do
    num = 14
    host = host(num)
    ext(num) |> Remote.external_update()

    rem1 = Remote.get_by(host: host)
    rem2 = Remote.get_by(id: rem1.id)

    assert rem1.id === rem2.id
  end

  test "get_by bad params" do
    msg = capture_log(fn -> Remote.get_by(foo: "foo") end)

    assert(msg =~ "bad arg")
  end

  test "all Remotes" do
    ext(1) |> Remote.external_update()
    remotes = Remote.all()

    is_remote = if Enum.empty?(remotes), do: nil, else: %Remote{} = hd(remotes)

    assert is_list(remotes) and is_remote
  end

  test "ota_update_list(:all)" do
    ota_list = Remote.ota_update_list(:all)
    first = [ota_list] |> List.flatten() |> hd

    assert is_list(ota_list)
    assert %{name: _, host: _} = first
  end

  test "ota_update_list(integer)" do
    num = 14
    host = host(num)
    ext(num) |> Remote.external_update()

    rem1 = Remote.get_by(host: host)

    ota_list = Remote.ota_update_list(rem1.id)
    first = [ota_list] |> List.flatten() |> hd()

    assert is_list(ota_list)
    assert %{name: _, host: _} = first
  end

  test "ota_update_list(name)" do
    num = 14
    host = host(num)
    ext(num) |> Remote.external_update()

    rem1 = Remote.get_by(host: host)

    ota_list = Remote.ota_update_list(rem1.name)
    first = [ota_list] |> List.flatten() |> hd()

    assert is_list(ota_list)
    assert %{name: _, host: _} = first
  end

  test "ota_update_list(host)" do
    num = 14
    host = host(num)
    ext(num) |> Remote.external_update()

    ota_list = Remote.ota_update_list(host)
    first = [ota_list] |> List.flatten() |> hd()

    assert is_list(ota_list)
    assert %{name: _, host: _} = first
  end

  test "ota_update_list(list_of_hosts)" do
    host_ids = [14, 15, 16, 17]

    hosts =
      for id <- host_ids do
        ext(id) |> Remote.external_update()
        host(id)
      end

    ota_list = Remote.ota_update_list(hosts)
    first = [ota_list] |> List.flatten() |> hd()

    assert is_list(ota_list)
    assert %{name: _, host: _} = first
    assert 4 == length(ota_list)
  end

  @tag :ota
  test "OTA update (unsupported)" do
    msg =
      capture_log(fn ->
        Remote.ota_update(:bad, log: true)
      end)

    assert msg =~ "unsupported"
  end

  @tag :ota
  test "OTA update (main)" do
    n = 10
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    msg =
      capture_log(fn ->
        Remote.ota_update(rem.name, reboot_delay_ms: 1000, log: true)
      end)

    assert msg =~ "ota url"
  end

  test "remote restart" do
    n = 12
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    res = Remote.restart(rem.id, reboot_delay_ms: 0, log: false)

    assert res == :ok
  end

  test "can deprecate a Remote" do
    n = 15
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    {rc, res} = Remote.deprecate(rem.id)

    assert rc == :ok and String.contains?(res.name, "~")
  end
end
