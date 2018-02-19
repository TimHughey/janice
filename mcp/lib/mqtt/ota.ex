defmodule Mqtt.OTA do
  @moduledoc """
  """

  require Logger
  use Timex

  alias Mqtt.Client

  @ota_begin_cmd "ota.begin"
  @ota_end_cmd "ota.end"

  def send_begin do
    %{}
    |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
    |> Map.put(:cmd, @ota_begin_cmd)
    |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
    |> Map.put(:delay, "10")
    |> json()
    |> Client.publish()
  end

  def send_end do
    %{}
    |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
    |> Map.put(:cmd, @ota_end_cmd)
    |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
    |> json()
    |> Client.publish()
  end

  def json(%{} = c) do
    Jason.encode!(c)
  end
end
