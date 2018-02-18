defmodule RemoteTest do
  use ExUnit.Case, async: true
  use Timex

  def test_host1, do: "mcr.0102030405"

  setup_all do
    :ok
  end

  test "process well formed external remote update" do
    eu = %{
      host: test_host1(),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix()
    }

    res = Remote.external_update(eu)

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: test_host1()}
    res = Remote.external_update(eu)

    assert res === :error
  end

  test "mark as seen (no delay)" do
    res = Remote.mark_as_seen(test_host1(), Timex.now() |> Timex.to_unix())

    assert test_host1() === res
  end

  test "mark as seen (30 sec delay)" do
    :timer.sleep(11 * 1000)

    res = Remote.mark_as_seen(test_host1(), Timex.now() |> Timex.to_unix())

    assert test_host1() === res
  end
end
