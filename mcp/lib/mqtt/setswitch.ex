defmodule Mqtt.SetSwitch do
  @moduledoc """
  """

  require Logger
  use Timex

  @setswitch_cmd "set.switch"

  @doc ~S"""
  Create a setswitch command with all map values required set to appropriate values

   ##Examples:
    iex> new_states = [%{"pio": 0, "state": true}, %{"pio": 1, "state": false}]
    ...> c = Mqtt.SetSwitch.new_cmd.setswitch("device", new_states, "uuid")
    ...> %Mqtt.SetSwitch{cmd: "setswitch", mtime: cmd_time} = c
    ...> (cmd_time > 0) and Map.has_key?(c, :states)
    true
  """
  def new_cmd(device, states, refid)
      when is_binary(device) and is_list(states) and is_binary(refid) do
    cmd =
      %{}
      |> Map.put(:vsn, 1)
      |> Map.put(:cmd, @setswitch_cmd)
      |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
      |> Map.put_new(:switch, device)
      |> Map.put_new(:states, states)
      |> Map.put_new(:refid, refid)

    Logger.debug(fn -> "sw_cmd: #{inspect(cmd)}" end)
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
