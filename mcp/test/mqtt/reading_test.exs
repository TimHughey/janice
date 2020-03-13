defmodule Mcp.ReadingTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  doctest Mqtt.Reading
  doctest Mqtt.SetPulseWidth

  alias Mqtt.Reading

  setup_all do
    :ok
  end

  @moduletag :reading
  test "detect bad metadata" do
    bad_msg = %{
      host: "other-macaddr",
      device: "ds/28.000",
      mtime: 1_506_867_918,
      type: "temp",
      tc: 20.1,
      tf: 80.1
    }

    fun = fn ->
      bad_msg |> Mqtt.Reading.metadata?()
    end

    msg = capture_log(fun)

    assert msg =~ "bad metadata"
  end

  test "can unpack a MessagePack formatted message" do
    r1 = %{
      host: "mcr.macaddr",
      device: "ds/28.0000",
      mtime: 1_506_867_918,
      type: "temp",
      tc: 20.1,
      tf: 80.1
    }

    {rc1, packed} = Msgpax.pack(r1)
    packed_bin = IO.iodata_to_binary(packed)

    {rc2, r2} = Msgpax.unpack(packed)

    {rc3, r3} = Reading.decode(packed_bin)

    assert rc1 == :ok
    assert rc2 == :ok
    assert rc3 == :ok
    assert r1.host == Map.get(r2, "host")
    assert r1.host == r3.host
    assert is_map(r3)
    assert Map.has_key?(r3, :msgpack)
  end
end
