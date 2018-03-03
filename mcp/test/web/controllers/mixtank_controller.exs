defmodule MixtankControllerTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  use Timex

  setup do
    :ok
  end

  setup_all do
    # Dutycycle.delete_all(:dangerous)
    # _dc = new_dutycycle(99) |> Dutycycle.add()
    :ok
  end

  test "true is true" do
    assert true === true
  end
end
