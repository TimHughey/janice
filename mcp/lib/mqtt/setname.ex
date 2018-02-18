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
      |> Map.put_new(:host, String.replace_prefix(name, "mcr.", ""))
      |> Map.put_new(:name, name)

    Logger.debug(fn -> "name_cmd: #{inspect(cmd)}" end)
    cmd
  end

  @doc ~S"""
  Generate JSON for a command

  ##Examples:
   iex> c = Mqtt.setswitch([%{p0: true}, %{p1: false}], "uuid")
   ...> json = Mqtt.SetSwitch.json(c)
   ...> parsed_cmd = Jason.Parser.parse!(json, [keys: :atoms!,
   ...>                                   as: Mqtt.SetSwitch])
   ...> parsed_cmd === Map.from_struct(c)
   true
  """
  def json(%{} = c) do
    Jason.encode!(c)
  end
end
