defmodule RemoteTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def test_host1, do: "mcr.0102030401"
  def test_host2, do: "mcr.0102030402"
  def test_host3, do: "mcr.0102030403"
  def test_host4, do: "mcr.0102030404"
  def test_host5, do: "mcr.0102030405"
  def test_host6, do: "mcr.0102030406"
  def test_host7, do: "mcr.0102030407"

  def test_name1, do: "test_name1"
  def test_name2, do: "test_name2"
  def test_name3, do: "test_name3"
  def test_name4, do: "test_name4"
  def test_name5, do: "test_name5"
  def test_name6, do: "test_name6"
  def test_name7, do: "test_name7"

  def test_ext1,
    do: %{
      host: test_host1(),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_ext2,
    do: %{
      host: test_host2(),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_ext3,
    do: %{
      host: test_host3(),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_ext4,
    do: %{
      host: test_host4(),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_ext5,
    do: %{
      host: test_host5(),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_ext6,
    do: %{
      host: test_host6(),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def test_preferred_vsn,
    do: %{
      host: test_host7(),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  setup_all do
    Remote.delete_all(:dangerous)
    :ok
  end

  test "process well formed external remote update" do
    res = test_ext1() |> Remote.external_update()

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: test_host1(), log: false}
    res = Remote.external_update(eu)

    assert res === :error
  end

  test "mark as seen (default threshold)" do
    test_ext6() |> Remote.external_update()
    before_mark = Remote.get_by(host: test_host6())

    Remote.mark_as_seen(test_host1(), Timex.now() |> Timex.to_unix())

    after_mark = Remote.get_by(host: test_host6())

    assert before_mark.last_seen_at === after_mark.last_seen_at
  end

  test "mark as seen (zero threshold)" do
    test_ext5() |> Remote.external_update()
    before_mark = Remote.get_by(host: test_host5())
    :timer.sleep(1500)
    Remote.mark_as_seen(test_host5(), Timex.now() |> Timex.to_unix(), 0)
    after_mark = Remote.get_by(host: test_host5())

    assert Timex.compare(after_mark.last_seen_at, before_mark.last_seen_at) == 1
  end

  test "change a name" do
    test_ext2() |> Remote.external_update()

    res = Remote.change_name(test_host2(), test_name2())
    %Remote{name: name} = Remote.get_by(name: test_name2())

    assert res === :ok and name === test_name2()
  end

  test "change a name (name in use)" do
    test_ext1() |> Remote.external_update()

    Remote.change_name(test_host1(), test_name1())
    res = Remote.change_name(test_host2(), test_name1())

    assert res === :name_in_use
  end

  test "get_by(name: name)" do
    test_ext3() |> Remote.external_update()

    Remote.change_name(test_host3(), test_name3())
    %Remote{name: name} = Remote.get_by(name: test_name3())

    assert name === test_name3()
  end

  test "get_by(name: name, only: [:last_seen_at, :last_start_at])" do
    test_ext3() |> Remote.external_update()
    result = Remote.get_by(host: test_host3(), only: [:last_seen_at, :last_start_at])

    seen = if is_map(result), do: Map.get(result, :last_seen_at, nil), else: result
    start = if is_map(result), do: Map.get(result, :last_start_at, nil), else: result

    refute is_nil(seen) and is_nil(start)
  end

  test "get_by(name: name, only: :last_seen_at)" do
    test_ext3() |> Remote.external_update()
    result = Remote.get_by(host: test_host3(), only: :last_seen_at)

    last = if is_map(result), do: Map.get(result, :last_seen_at, nil), else: result

    refute is_nil(last)
  end

  test "get_by bad params" do
    msg = capture_log(fn -> Remote.get_by(foo: "foo") end)

    assert(msg =~ "bad arg")
  end

  test "get vsn preference" do
    test_ext4() |> Remote.external_update()
    Remote.change_name(test_host4(), test_name4())
    pref = Remote.vsn_preference(name: test_name4())

    assert(pref === "stable")
  end

  test "get vsn preference non-existent host" do
    assert Remote.vsn_preference(name: "foobar") === "not_found"
  end

  test "external update started log message" do
    fun = fn -> Map.put(test_ext4(), :log, true) |> Remote.external_update() end
    msg = capture_log(fun)

    assert msg =~ "started"
  end

  test "all Remote" do
    test_ext1() |> Remote.external_update()
    remotes = Remote.all()

    is_remote = if Enum.empty?(remotes), do: nil, else: %Remote{} = hd(remotes)

    assert is_list(remotes) and is_remote
  end
end
