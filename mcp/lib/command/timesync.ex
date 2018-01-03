defmodule Command.Timesync do
@moduledoc """
"""

alias __MODULE__

require Logger
use Timex
use Task

import Mqtt.Client, only: [publish: 1]

@undef "undef"
@timesync "time.sync"

@derive [Poison.Encoder]
defstruct cmd: @undef,
          mtime: Timex.zero(),
          version: 1

def run(opts) do
  frequency = opts.timesync.frequency
  loops = opts.timesync.loops
  forever = opts.timesync.forever
  log = opts.timesync.log
  single = opts.timesync.single

  msg = Timesync.new_cmd() |> Timesync.json()
  res = publish_opts(opts.feeds.cmd, msg) |> publish()

  log && Logger.info fn -> "published timesync #{inspect(res)}" end

  opts = update_in(opts, [:timesync, :loops], fn(x) -> x-1 end)

  cond do
    single    -> :ok
    forever or (loops-1) > 0 -> :timer.sleep(frequency)
                                run(opts)
    true                     -> :executed_requested_loops
  end
end

def send(%{timesync: _} = opts) do
  opts = update_in(opts, [:timesync, :single], fn(_) -> true end)

  run(opts)
end

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

defp publish_opts(topic, msg)
when is_binary(topic) and is_binary(msg) do
  [topic: topic, message: msg, dup: 0, qos: 0, retain: 0]
end

end
