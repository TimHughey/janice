defmodule MqttInboundMessageTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Janice.TimeSupport

  def preferred_vsn, do: "b4edefc"

  def num(n), do: String.pad_leading(Integer.to_string(n), 3, "0")
  def host(n), do: "mcr.inbound" <> num(n)
  def name(n), do: "inbound" <> num(n)

  def device(n), do: "ds/inbound" <> num(n)
  def device_pio(n, pio), do: device(n) <> ":#{pio}"

  def pios(n, pos), do: for(i <- 0..(n - 1), do: %{pio: i, state: pos})

  def base_ext(num),
    do: %{
      host: host(num),
      name: name(num),
      # hw: "esp32",
      # vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false
    }

  def freeram_ext(num) do
    base = base_ext(num)

    freeram = %{type: "stats", freeram: :rand.uniform(100_000)}

    Map.merge(base, freeram)
  end

  def freeram_ext_msg(n) do
    %{direction: :in, payload: freeram_ext(n) |> Jason.encode!()}
    |> Mqtt.Inbound.process()
  end

  def random_float do
    a = :rand.uniform(25)
    b = :rand.uniform(100)

    a + b * 0.1
  end

  def rh_ext(num) do
    temp = temp_ext(num)
    rh = random_float()

    sensor = %{
      type: "relhum",
      rh: rh
    }

    Map.merge(temp, sensor)
  end

  def rh_ext_msg(n \\ 0) do
    %{direction: :in, payload: rh_ext(n) |> Jason.encode!()}
    |> Mqtt.Inbound.process()
  end

  def simple_text_ext(num) do
    base = base_ext(num)

    sw = %{
      type: "text",
      text: "simple text message",
      log: false
    }

    Map.merge(base, sw)
  end

  def simple_text_ext_msg(n \\ 0) do
    %{direction: :in, payload: simple_text_ext(n) |> Jason.encode!()}
    |> Mqtt.Inbound.process()
  end

  def switch_ext(num, num_pios, pos) do
    base = base_ext(num)

    sw = %{
      type: "switch",
      device: device(num),
      pio_count: num_pios,
      states: pios(8, pos),
      dev_latency_us: :rand.uniform(1024) + 3000
    }

    Map.merge(base, sw)
  end

  def switch_ext_msg(n \\ 0) do
    %{direction: :in, payload: switch_ext(n, 8, false) |> Jason.encode!()}
    |> Mqtt.Inbound.process()
  end

  def temp_ext(num) do
    base = base_ext(num)
    tc = random_float()
    tf = tc * (9.0 / 5.0) + 32.0

    sensor = %{
      type: "temp",
      device: device(num),
      tc: tc,
      tf: tf
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n \\ 0) do
    %{direction: :in, payload: temp_ext(n) |> Jason.encode!()}
    |> Mqtt.Inbound.process()
  end

  setup_all do
    :ok
  end

  test "inbound Simple Text message" do
    res = simple_text_ext_msg(0)
    assert res == :ok
  end

  test "inbound Switch message" do
    res = switch_ext_msg(0)

    assert res === :ok
  end

  test "inbound Sensor (temperature) message" do
    res = temp_ext_msg(2)

    assert res === :ok
  end

  test "inbound Sensor (relhum) message" do
    res = rh_ext_msg(3)

    assert res === :ok
  end

  test "inbound freeram message" do
    res = freeram_ext_msg(4)

    assert res === :ok
  end

  test "GenServer can handle unknown handle_call() msg" do
    fun = fn -> Mqtt.Inbound.handle_call({:bad_msg}, :from, %{}) end
    msg = capture_log(fun)

    # assert msg =~ host(1)
    assert msg =~ "unknown handle_call"
    assert msg =~ "bad_msg"
  end

  test "GenServer can handle unknown handle_cast() msg" do
    fun = fn -> Mqtt.Inbound.handle_cast({:bad_msg}, %{}) end
    msg = capture_log(fun)

    # assert msg =~ host(1)
    assert msg =~ "unknown handle_cast"
    assert msg =~ "bad_msg"
  end

  test "GenServer can handle unknown handle_info() msg" do
    fun = fn -> Mqtt.Inbound.handle_info({:bad_msg}, %{}) end
    msg = capture_log(fun)

    # assert msg =~ host(1)
    assert msg =~ "unknown handle_info"
    assert msg =~ "bad_msg"
  end

  test "can get additional message flags" do
    rc = Mqtt.Inbound.additional_message_flags()

    assert is_map(rc)
  end

  test "can set additional message flags" do
    {rc, new_flags} = Mqtt.Inbound.additional_message_flags(set: [foobar: true])

    assert rc == :ok
    assert is_map(new_flags)
    assert Map.has_key?(new_flags, :foobar)
  end

  test "can merge additional message flags" do
    initial_flag_count = Mqtt.Inbound.additional_message_flags() |> Enum.count()

    {rc, new_flags} =
      Mqtt.Inbound.additional_message_flags(merge: [another_flag: true])

    assert rc == :ok
    assert is_map(new_flags)
    assert Map.has_key?(new_flags, :another_flag)
    assert Enum.count(new_flags) >= initial_flag_count + 1
  end

  test "setting additional message flags detects bad opts" do
    rc = Mqtt.Inbound.additional_message_flags(foobar: [hello: true])

    assert rc == :bad_opts
  end
end
