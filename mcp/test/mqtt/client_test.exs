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

  test "toggle runtime metrics" do
    rc = Mqtt.Client.runtime_metrics(:toggle)

    assert %{is: _, was: _} = rc
  end

  test "turn runtime metrics off" do
    rc = Mqtt.Client.runtime_metrics(false)

    assert %{is: false, was: _} = rc
  end

  test "turn runtime metrics on" do
    rc = Mqtt.Client.runtime_metrics(true)

    assert %{is: true, was: _} = rc
  end

  test "can get current runtime metrics flag" do
    rc = Mqtt.Client.runtime_metrics()

    assert is_boolean(rc)
  end
end
