defmodule MqttClientTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  setup_all do
    :ok
  end

  test "Mqtt.Client is running" do
    existing_pid = Process.whereis(Mqtt.Client)

    assert is_pid(existing_pid)
  end

  test "subscribe to report feed" do
    msg = capture_log(fn -> Mqtt.Client.report_subscribe() end)

    assert msg =~ "report"
  end

  test "send timesync" do
    rc = Mqtt.Client.send_timesync()

    assert rc == {:ok}
  end
end
