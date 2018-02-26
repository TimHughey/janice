defmodule FactEngineMetricTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.010203040" <> Integer.to_string(num)
  def name(num), do: "test_name" <> Integer.to_string(num)

  def ext(num, engine),
    do: %{
      vsn: preferred_vsn(),
      host: host(num),
      type: "mcr_engine",
      metric: "engine_phase",
      engine: engine,
      discover_us: 0,
      convert_us: 0,
      report_us: 0,
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  test "bad input reading" do
    msg =
      capture_log(fn ->
        ext(0, "dsTest") |> Map.delete(:type)
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

    assert res === :ok
  end

  test "reading with convert_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:convert_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.convert_us > 0 and res == :ok
  end

  test "reading with discover_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:discover_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.discover_us > 0 and res == :ok
  end

  test "reading with report_us > 0" do
    raw = ext(0, "dsTest") |> Map.put(:report_us, 1_000_000)
    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.report_us > 0 and res == :ok
  end

  test "reading with all fields > 0" do
    raw =
      ext(0, "dsTest") |> Map.put(:convert_us, 2_000_000) |> Map.put(:discover_us, 2_000_000)
      |> Map.put(:report_us, 2_000_000)

    pt = Fact.EngineMetric.make_point(raw)
    res = Fact.EngineMetric.record(raw)

    assert pt.fields.convert_us > 0 and pt.fields.discover_us > 0 and pt.fields.report_us > 0 and
             res == :ok
  end
end
