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
      mtime: TimeSupport.unix_now(:seconds),
      log: false
    }

  setup_all do
    [log: false]
  end

  @tag :ota
  test "send OTA" do
    ext(0) |> Remote.external_update()
    hosts = [host(0)]

    rc = OTA.send(update_hosts: hosts, log: true, start_delay_ms: 100)

    assert rc == :ok
  end
end
