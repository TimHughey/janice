defmodule ReadingTest do
  @moduledoc :false

  use ExUnit.Case, async: true
  alias Mcp.Reading

  @name "test_reading"
  @kind "temperature"
  @good_val {100, {:ok, 85.0}}
  @err_val {100, {:error, 0.0}}
  @long_ttl 30_000
  @short_ttl 100

  defp good_reading(ttl) do
    Reading.create(@name, @kind, @good_val, ttl)
  end

  defp bad_reading(ttl) do
    Reading.create(@name, @kind, @err_val, ttl)
  end

  test "can create a good Reading?" do
    r = good_reading(@long_ttl)
    assert Reading.valid?(r) and not Reading.invalid?(r)
  end

  test "can create a bad Reading" do
    r = bad_reading(@long_ttl)
    assert not Reading.valid?(r) and Reading.invalid?(r)
  end

  test "does a Reading remain current before ttl expires?" do
    r = good_reading(@long_ttl)
    assert Reading.current?(r)
  end

  test "does a Reading expire via ttl?" do
    r = good_reading(@short_ttl)
    :timer.sleep(@short_ttl + 10)
    assert not Reading.current?(r)
  end

  test "can detect that a Reading is a temperature?" do
    r = good_reading(@long_ttl)

    assert Reading.temperature?(r)
  end
end
