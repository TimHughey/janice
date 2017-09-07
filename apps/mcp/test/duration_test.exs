defmodule DurationTest do
  @moduledoc :false

  use Timex
  use ExUnit.Case, async: true
  alias Mcp.Duration

  @metric "test_metric"
  @val 95.0

  test "can create a Duration and retrieve val?" do
    d = Duration.create(@metric, @val)
    assert Duration.val(d) == @val
  end

  test "can create a Duration and timestamp is current?" do
    d = Duration.create(@metric, @val)
    now = Timex.now()

    assert Timex.diff(now, Duration.ts(d), :milliseconds) < 100
  end
end
