defmodule RemoteTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  alias Janice.TimeSupport

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.remote" <> String.pad_leading(Integer.to_string(num), 3, "0")
  def name(num), do: "remote" <> String.pad_leading(Integer.to_string(num), 3, "0")

  def ext(num),
    do: %{
      host: host(num),
      type: "remote_runtime",
      hw: "esp32",
      vsn: "1234567",
      mtime: TimeSupport.unix_now(:seconds),
      log: false,
      reset_reason: "software reset",
      batt_mv: 3800,
      ap_rssi: -45,
      ap_pri_chan: 6,
      ap_sec_chan: 1,
      heap_min: 100 * 1024,
      heap_free: 101 * 1024
    }

  def runtime(m), do: Map.put(m, :type, "remote_runtime")
  def boot(m), do: Map.put(m, :type, "boot")

  setup_all do
    ext(99) |> boot() |> Remote.external_update()
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
      |> Map.put(:mtime, later_mtime)
      |> Remote.external_update()

    rem = Remote.get_by(host: host(16))

    assert res === :ok
    assert Timex.to_unix(rem.last_start_at) >= initial_mtime
  end

  test "can create a changeset from an external update" do
    rem = Remote.get_by(host: host(1))
    eu = ext(1) |> boot() |> Map.put(:reset_reason, "test")

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

  test "change vsn preference to head" do
    ext(9) |> Remote.external_update()
    r = Remote.get_by(host: host(9))
    res = Remote.change_vsn_preference(r.id, "head")

    assert res === "head"
  end

  test "change vsn preference to bad preference" do
    ext(9) |> Remote.external_update()
    r = Remote.get_by(host: host(9))
    res = Remote.change_vsn_preference(r.id, "bad")

    assert res === :error
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

  test "get vsn preference" do
    ext(4) |> Remote.external_update()
    Remote.change_name(host(4), name(4))
    pref = Remote.vsn_preference(name: name(4))

    assert(pref === "stable")
  end

  test "get vsn preference non-existent host" do
    assert Remote.vsn_preference(name: "foobar") === "not_found"
  end

  test "external update started log message" do
    fun = fn -> Map.put(ext(4), :log, true) |> boot() |> Remote.external_update() end
    msg = capture_log(fun)

    assert msg =~ host(4)
    assert msg =~ "boot"
  end

  test "all Remotes" do
    ext(1) |> Remote.external_update()
    remotes = Remote.all()

    is_remote = if Enum.empty?(remotes), do: nil, else: %Remote{} = hd(remotes)

    assert is_list(remotes) and is_remote
  end

  @tag :ota
  test "OTA update all" do
    msg =
      capture_log(fn ->
        Remote.ota_update(:all, start_delay_ms: 10, reboot_delay_ms: 1000, log: true)
      end)

    assert msg =~ "needs update"
  end

  @tag :ota
  test "OTA update by name" do
    n = 10
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    msg =
      capture_log(fn ->
        Remote.ota_update(rem.id, start_delay_ms: 100, reboot_delay_ms: 1000, log: true)
      end)

    assert msg =~ "needs update"
  end

  @tag :ota
  test "OTA single (by name, force)" do
    n = 11
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    msg =
      capture_log(fn ->
        Remote.ota_update_single(rem.name, force: true, start_delay_ms: 1, log: true)
      end)

    assert msg =~ "needs update"
  end

  test "remote restart" do
    n = 12
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    res = Remote.restart(rem.id, delay_ms: 0, log: false)

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
