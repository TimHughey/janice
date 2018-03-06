defmodule OTATest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  use Timex

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.ota" <> Integer.to_string(num)
  def name(num), do: "ota" <> Integer.to_string(num)

  def ext(num),
    do: %{
      host: host(num),
      hw: "esp32",
      vsn: "1234567",
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  setup_all do
    :ok
  end

  @tag :ota
  test "transmit OTA" do
    ext(0) |> Remote.external_update()
    hosts = [host(0)]

    {_rc, pid} = OTA.transmit(update_hosts: hosts, log: false, return_task: true)

    checks =
      for _i <- 0..20 do
        :timer.sleep(500)
        Process.alive?(pid)
      end

    started = true in checks
    ended = false in checks

    assert started
    assert ended
  end
end
