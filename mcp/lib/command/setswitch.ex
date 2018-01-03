defmodule Command.SetSwitch do
@moduledoc """
"""

alias __MODULE__

require Logger
use Timex

@undef "undef"
@setswitch "set.switch"

@derive [Poison.Encoder]
defstruct cmd: @undef,
          mtime: Timex.zero(),
          version: 1

@doc ~S"""
Create a setswitch command with all map values required set to appropriate values

 ##Examples:
  iex> new_states = [%{"pio": 0, "state": true}, %{"pio": 1, "state": false}]
  ...> c = Command.SetSwitch.new_cmd.setswitch("device", new_states, "uuid")
  ...> %Command.SetSwitch{cmd: "setswitch", mtime: cmd_time} = c
  ...> (cmd_time > 0) and Map.has_key?(c, :states)
  true
"""
def new_cmd(device, states, refid)
when is_binary(device) and is_list(states) and is_binary(refid) do
  cmd = %SetSwitch{} |>
    Map.put(:cmd, @setswitch) |>
    mtime() |>
    Map.put_new(:switch, device) |>
    Map.put_new(:states, states) |>
    Map.put_new(:refid, refid)

  Logger.debug fn -> "sw_cmd: #{inspect(cmd)}" end
  cmd
end

defp mtime(%SetSwitch{} = c) do
  %SetSwitch{c | mtime: Timex.now() |> Timex.to_unix()}
end

@doc ~S"""
Generate JSON for a command

##Examples:
 iex> c = Command.setswitch([%{p0: true}, %{p1: false}], "uuid")
 ...> json = Command.SetSwitch.json(c)
 ...> parsed_cmd = Poison.Parser.parse!(json, [keys: :atoms!,
 ...>                                   as: Command.SetSwitch])
 ...> parsed_cmd === Map.from_struct(c)
 true
"""
def json(%SetSwitch{} = c) do
  Poison.encode!(c)
end

end
