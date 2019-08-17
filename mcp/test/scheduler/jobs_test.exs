defmodule JobsTest do
  @moduledoc false

  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog

  @moduletag :jobs

  setup_all do
    :ok
  end

  setup_all do
    :ok
  end

  test "sensor reading purge" do
    res = Janice.Jobs.purge_readings(days: -1)

    assert is_list(res)
  end

  test "sensor reading purge handles bad opts" do
    res = Janice.Jobs.purge_readings(days: 10)

    assert res === :bad_opts
  end

  test "the truth will set you free" do
    assert true === true
    refute false
  end
end
