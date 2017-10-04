defmodule Command.Timesync do
@moduledoc """
"""

alias __MODULE__

require Logger
use Timex

@undef "undef"
@timesync "time.sync"

@derive [Poison.Encoder]
defstruct cmd: @undef,
          mtime: Timex.zero(),
          version: 1

@doc ~S"""
Create a timesync command with all map values required set to appropriate values

 ##Examples:
  iex> c = Mcp.Cmd.timesync
  ...> %Mcp.Cmd{cmd: "time.sync", mtime: cmd_time, version: 1} = c
  ...> cmd_time > 0
  true
"""

def new_cmd do
  %Timesync{} |>
    Map.put(:cmd, @timesync) |>
    mtime()
end

defp mtime(%Timesync{} = c) do
  %Timesync{c | mtime: Timex.now() |> Timex.to_unix()}
end

@doc ~S"""
Generate JSON for a command

##Examples:
 iex> c = Command.Timesync.setswitch([%{p0: true}, %{p1: false}], "uuid")
 ...> json = Command.Timesync.json(c)
 ...> parsed_cmd = Poison.Parser.parse!(json, [keys: :atoms!,
                                        as: Command.Timesync])
 ...> parsed_cmd === Map.from_struct(c)
 true
"""
def json(%Timesync{} = c) do
  Poison.encode!(c)
end

end
