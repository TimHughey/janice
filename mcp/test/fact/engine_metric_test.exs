defmodule FactEngineMetricTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Janice.TimeSupport

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.010203040" <> Integer.to_string(num)
  def name(num), do: "test_name" <> Integer.to_string(num)

  def ext(num, engine),
    do: %{
      vsn: preferred_vsn(),
      host: host(num),
      name: name(0),
      type: "mcr_stat",
      metric: "engine_phase",
      engine: engine,
      discover_us: 0,
      convert_us: 0,
      report_us: 0,
      switch_cmd_us: 0,
      mtime: TimeSupport.unix_now(:second),
      log: false
    }

  test "can create Fact.EngineMetric series" do
    s = %Fact.EngineMetric{}

    assert is_map(s)
  end

  test "bad input reading" do
    msg =
      capture_log(fn ->
        ext(0, "dsTest")
        |> Map.delete(:type)
        |> Fact.EngineMetric.make_point()
      end)

    assert msg =~ "no match"
  end

  test "reading is a valid EngineMetric?" do
    check = ext(0, "dsTest") |> Fact.EngineMetric.valid?()

    assert check
  end

  test "reading is NOT a valid EngineMetric?" do
    check = ext(0, "dsTest") |> Map.delete(:type) |> Fact.EngineMetric.valid?()

    refute check
  end

  test "reading with all zeroes" do
    pt = ext(0, "dsTest")
    res = Fact.EngineMetric.record(pt)

    assert res === :ok or res == {:not_recorded}
  end

  test "reading with convert_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:convert_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.convert_us > 0 and (res == :ok or res == {:not_recorded})
  end

  test "reading with discover_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:discover_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.discover_us > 0 and (res == :ok or res == {:not_recorded})
  end

  test "reading with report_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:report_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.report_us > 0 and (res == :ok or res == {:not_recorded})
  end

  test "reading with switch_cmd_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:switch_cmd_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.switch_cmd_us > 0 and
             (res == :ok or res == {:not_recorded})
  end

  test "reading with all fields > 0" do
    raw =
      ext(0, "dsTest")
      |> Map.put(:convert_us, 2_000_000)
      |> Map.put(:discover_us, 2_000_000)
      |> Map.put(:report_us, 2_000_000)
      |> Map.put(:switch_cmd_us, 2_000_000)

    pt = Fact.EngineMetric.make_point(raw)
    res = Map.put_new(raw, :record, true) |> Fact.EngineMetric.record()

    assert pt.fields.convert_us > 0 and pt.fields.discover_us > 0 and
             pt.fields.report_us > 0 and
             res == :ok
  end
end
