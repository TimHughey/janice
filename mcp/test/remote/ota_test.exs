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
  test "send OTA with correct list format" do
    ext(0) |> Remote.external_update()
    hosts = [%{host: host(0), name: name(0)}]

    list = OTA.send_cmd(update_list: hosts, log: false)

    assert is_list(list)
    refute Enum.empty?(list)
    assert {_name, _host, :ok} = hd(list)
  end

  @tag :ota
  test "send OTA with incorrect list format" do
    ext(0) |> Remote.external_update()
    hosts = [host(0)]

    {rc, list} = OTA.send_cmd(update_hosts: hosts, log: false)

    assert is_list(list)
    refute Enum.empty?(list)
    assert rc == :send_bad_opts
  end
end
