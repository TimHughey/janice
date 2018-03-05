defmodule Mcp.ReadingTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  doctest Mqtt.Reading

  setup_all do
    :ok
  end

  test "detect bad metadata" do
    json = ~s({"vsn": 0, "host": "other-macaddr", "device": "ds/28.0000",
        "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})

    fun = fn -> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.metadata?() end

    msg = capture_log(fun)

    assert msg =~ "bad metadata"
  end
end
