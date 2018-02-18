defmodule RemoteTest do
  use ExUnit.Case, async: true
  use Timex

  setup_all do
    :ok
  end

  test "process well formed external remote update" do
    eu = %{
      host: "mcr.0102034005",
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix()
    }

    res = Remote.external_update(eu)

    assert res === :ok
  end

  test "process poorly formed external remote update" do
    eu = %{host: "mcr.0102030405"}
    res = Remote.external_update(eu)

    assert res === :error
  end
end
