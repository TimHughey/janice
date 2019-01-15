defmodule OTATest do
  @moduledoc false

  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog

  alias Janice.TimeSupport

  def preferred_vsn, do: "b4edefc"
  def host(num), do: "mcr.ota" <> Integer.to_string(num)
  def name(num), do: "ota" <> Integer.to_string(num)

  def ext(num),
    do: %{
      host: host(num),
      hw: "esp32",
      vsn: "1234567",
      mtime: TimeSupport.unix_now(:seconds),
      log: false
    }

  setup_all do
    [log: false]
  end

  @tag :ota
  test "transmit OTA", context do
    log = Kernel.get_in(context, [:opts])

    ext(0) |> Remote.external_update()
    hosts = [host(0)]

    {_rc, pid} =
      OTA.transmit(update_hosts: hosts, log: log, start_delay_ms: 100, return_task: true)

    checks =
      for _i <- 0..990 do
        :timer.sleep(1)
        Process.alive?(pid)
      end

    started = true in checks
    ended = false in checks

    assert started
    assert ended
  end
end
