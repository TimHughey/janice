defmodule Mcp.Cmd do
@moduledoc """
"""

alias __MODULE__

require Logger
use Timex

@undef "undef"
@timesync "time.sync"
@setswitch "setswitch"

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

def timesync do
  %Cmd{} |>
    Map.put(:cmd, @timesync) |>
    mtime()
end

@doc ~S"""
Create a setswitch command with all map values required set to appropriate values

 ##Examples:
  iex> c = Mcp.Cmd.setswitch([%{p0: true}, %{p1: false}], 2, "uuid")
  ...> %Mcp.Cmd{cmd: "setswitch", mtime: cmd_time} =c
  ...> (cmd_time > 0) and Map.has_key?(c, :pio) and Map.has_key?(c, :pio_count)
  true
"""
def setswitch(pio, pio_count, refid)
when is_list(pio) and is_integer(pio_count) and is_binary(refid) do
  %Cmd{} |>
    Map.put(:cmd, @setswitch) |>
    mtime() |>
    Map.put_new(:pio, pio) |>
    Map.put_new(:pio_count, pio_count) |>
    Map.put_new(:ref_id, refid)
end

defp mtime(%Cmd{} = c) do
  %Cmd{c | mtime: Timex.now() |> Timex.to_unix()}
end

@doc ~S"""
Generate JSON for a command

##Examples:
 iex> c = Mcp.Cmd.setswitch([%{p0: true}, %{p1: false}], 2, "uuid")
 ...> json = Mcp.Cmd.json(c)
 ...> parsed_cmd = Poison.Parser.parse!(json, keys: :atoms!)
 ...> parsed_cmd === Map.from_struct(c)
 true
"""
def json(%Cmd{} = c) do
  Poison.encode!(c)
end

end
