defmodule Command.Timesync do
@moduledoc """
"""

alias __MODULE__

require Logger
use Timex
use Task

import Mqtt.Client, only: [publish: 1]
import Application, only: [get_env: 2]

@undef "undef"
@timesync "time.sync"

@derive [Poison.Encoder]
defstruct cmd: @undef,
          mtime: Timex.zero(),
          version: 1

def run(opts) do
  frequency = Keyword.get(opts, :frequency, 1000)
  loops = Keyword.get(opts, :loops, 1)
  forever = Keyword.get(opts, :forever, false)
  feed = Keyword.get(opts, :feed, false)
  log = Keyword.get(opts, :log, false)
  single = Keyword.get(opts, :single, false)


  if feed do
    msg = Timesync.new_cmd() |> Timesync.json()
    cmd = publish_opts(feed, msg)

    res = publish(cmd)

    log && Logger.info fn -> "published timesync #{inspect(res)}" end

    :timer.sleep(frequency)

    cond do
      single    -> :ok
      forever or (loops-1) > 0 -> Keyword.replace(opts, :loops, (loops-1)) |>
                                  run()
      true                     -> :executed_requested_loops

    end
  else
    :timesync_missing_config
  end
end

def send do
  opts = get_env(:mcp, Command.Control) |>
          Keyword.get(:timesync_opts) |>
          Keyword.put(:single, true)

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
