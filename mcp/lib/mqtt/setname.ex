defmodule Mqtt.SetName do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  @setname_cmd "set.name"

  def new_cmd(host, name)
      when is_binary(host) and is_binary(name) do
    cmd =
      %{}
      |> Map.put(:cmd, @setname_cmd)
      |> Map.put(:mtime, TimeSupport.unix_now(:second))
      |> Map.put_new(:host, host)
      |> Map.put_new(:name, String.replace_prefix(name, "mcr.", ""))

    Logger.debug(["name_cmd: ", inspect(cmd, pretty: true)])
    cmd
  end

  def json(%{} = c) do
    Jason.encode!(c)
  end
end
