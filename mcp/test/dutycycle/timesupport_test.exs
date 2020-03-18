defmodule TimeSupportTest do
  @moduledoc false

  # must be async: false because tests build on each other
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  use Timex

  import Janice.TimeSupport, only: [ms: 1, utc_now: 0, utc_shift: 1]
  alias Janice.TimeSupport

  setup do
    :ok
  end

  @moduletag :timesupport
  setup_all do
    :ok
  end

  test "can handle conversion of {:secs, x}" do
    val = 3
    res = ms({:secs, val})

    assert is_number(res)
    assert res === val * 1000
  end

  test "can handle conversion of {:mins, x}" do
    val = 3
    res = ms({:mins, val})

    assert is_number(res)
    assert res === ms({:secs, val * 60})
  end

  test "can handle conversion of {:hrs, x}" do
    val = 3
    res = ms({:hrs, val})

    assert is_number(res)
    assert res === ms({:mins, val * 60})
  end

  test "can handle conversion of {:days, x}" do
    val = 3
    res = ms({:days, val})

    assert is_number(res)
    assert res === ms({:hrs, val * 24})
  end

  test "can handle conversion of {:weeks, x}" do
    val = 3
    res = ms({:weeks, val})

    assert is_number(res)
    assert res === ms({:days, val * 7})
  end

  test "can handle conversion of {:months, x}" do
    val = 3
    res = ms({:months, val})

    assert is_number(res)
    assert res === ms({:weeks, val * 4})
  end

  test "can handle invalid options to ms()" do
    f1 = fn -> ms(:bad_opts) end
    f2 = fn -> ms({:secs, "12"}) end

    msg1 = capture_log(f1)
    msg2 = capture_log(f2)

    assert msg1 =~ "not supported"
    assert msg2 =~ "not supported"
  end

  test "can create a shifted UTC Timex.DateTime" do
    shifted = utc_shift(hours: -1)

    assert Timex.before?(shifted, utc_now())
  end

  test "can create a Duration from a list of opts" do
    d = TimeSupport.list_to_duration(minutes: 1, seconds: 1)

    assert Duration.to_seconds(d, truncate: true) == 61
  end
end
