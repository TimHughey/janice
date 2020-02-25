defmodule Mqtt.SetName do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  def new_cmd(host, name)
      when is_binary(host) and is_binary(name),
      do: %{
        cmd: "set.name",
        mtime: TimeSupport.unix_now(:second),
        host: host,
        name: String.replace_prefix(name, "mcr.", "")
      }

  def json(%{} = c) do
    Logger.info(["json encoding: ", inspect(c, pretty: true)])
    Jason.encode!(c)
  end
end
