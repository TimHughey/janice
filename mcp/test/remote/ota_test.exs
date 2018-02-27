defmodule OTATest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.010203040" <> Integer.to_string(num)
  def name(num), do: "test_name" <> Integer.to_string(num)

  def ext(num),
    do: %{
      host: host(num),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  setup_all do
    Remote.delete_all(:dangerous)
    :ok
  end

  test "transmit OTA" do
    msg = capture_log(fn -> OTA.transmit() end)

    assert msg =~ "ota final block size"
  end
end
