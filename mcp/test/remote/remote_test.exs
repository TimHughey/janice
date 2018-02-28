defmodule RemoteTest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.remote" <> String.pad_leading(Integer.to_string(num), 3, "0")
  def name(num), do: "remote" <> String.pad_leading(Integer.to_string(num), 3, "0")

  def ext(num),
    do: %{
      host: host(num),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  setup_all do
    ext(99) |> Remote.external_update()
    :ok
  end

  test "process well formed external remote update" do
    res = ext(1) |> Remote.external_update()

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: host(1), log: false}
    res = Remote.external_update(eu)

    assert res === :error
  end

  test "mark as seen (default threshold)" do
    ext(6) |> Remote.external_update()
    before_mark = Remote.get_by(host: host(6))

    Remote.mark_as_seen(host(1), Timex.now() |> Timex.to_unix())

    after_mark = Remote.get_by(host: host(6))

    assert before_mark.last_seen_at === after_mark.last_seen_at
  end

  test "mark as seen (zero threshold)" do
    ext(5) |> Remote.external_update()
    before_mark = Remote.get_by(host: host(5))
    :timer.sleep(1500)
    Remote.mark_as_seen(host(5), Timex.now() |> Timex.to_unix(), 0)
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
    fun = fn -> Map.put(ext(4), :log, true) |> Remote.external_update() end
    msg = capture_log(fun)

    assert msg =~ "started"
  end

  test "all Remote" do
    ext(1) |> Remote.external_update()
    remotes = Remote.all()

    is_remote = if Enum.empty?(remotes), do: nil, else: %Remote{} = hd(remotes)

    assert is_list(remotes) and is_remote
  end

  test "OTA update all" do
    msg = capture_log(fn -> Remote.ota_update(:all, transmit_delay_ms: 1) end)

    assert msg =~ "needs update"
  end

  test "OTA update by name" do
    n = 10
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))
    msg = capture_log(fn -> Remote.ota_update(rem.id, transmit_delay_ms: 1) end)

    assert msg =~ "needs update"
  end

  test "OTA single (by name, force)" do
    n = 11
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    msg =
      capture_log(fn -> Remote.ota_update_single(rem.name, force: true, transmit_delay_ms: 1) end)

    assert msg =~ "needs update"
  end

  test "remote restart" do
    n = 12
    ext(n) |> Remote.external_update()
    rem = Remote.get_by(host: host(n))

    res = Remote.restart(rem.id, delay_ms: 0)

    assert res == :ok
  end
end
