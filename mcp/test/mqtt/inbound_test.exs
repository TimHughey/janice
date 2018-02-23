defmodule MqttInboundMessageTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
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

  def test_ext1 do
    ~S({"vsn":"a8f350a","host":"mcr.30aea4288200","mtime":1519362603,"device":"ds/12606e21000000","read_us":14331,"type":"switch","pio_count":2,"states":[{"pio":0,"state":false},{"pio":1,"state":false}]})
  end

  setup_all do
    :ok
  end

  test "inbound Switch message" do
    res = test_ext1() |> Mqtt.InboundMessage.process()

    assert res === :ok
  end

  test "inbound message logging" do
    start = Mqtt.InboundMessage.log_json(log: true)
    test_ext1() |> Mqtt.InboundMessage.process()
    stop = Mqtt.InboundMessage.log_json(log: false)

    assert start === :log_open and stop === :log_closed
  end
end
