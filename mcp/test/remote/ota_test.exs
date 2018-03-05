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

  # test "transmit OTA" do
  #   {_rc, pid} = OTA.transmit(log: true, return_task: true)
  #
  #   got_task = is_pid(pid)
  #
  #   got_task && Task.await(pid)
  #
  #   assert got_task
  # end
end
