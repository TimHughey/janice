defmodule Mqtt.SetName do
  @moduledoc """
  """

  require Logger
  use Timex

  @setname_cmd "set.name"

  def new_cmd(host, name)
      when is_binary(host) and is_binary(name) do
    cmd =
      %{}
      |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
      |> Map.put(:cmd, @setname_cmd)
      |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
      |> Map.put_new(:host, host)
      |> Map.put_new(:name, String.replace_prefix(name, "mcr.", ""))

    Logger.debug(fn -> "name_cmd: #{inspect(cmd)}" end)
    cmd
  end

  def json(%{} = c) do
    Jason.encode!(c)
  end
end
