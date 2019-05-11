defmodule Mqtt.Timesync do
  @moduledoc false

  alias __MODULE__

  require Logger
  use Task

  import Mqtt.Client, only: [publish: 1]
  import Janice.TimeSupport, only: [ms: 1, unix_now: 1]

  @timesync_cmd "time.sync"

  def run(opts) do
    # reasonable defaults if configuration is not set
    frequency = Map.get(opts, :frequency, {:mins, 1})
    loops = Map.get(opts, :loops, 0)
    forever = Map.get(opts, :forever, true)
    log = Map.get(opts, :log, false)
    single = Map.get(opts, :single, false)

    # construct the timesync message
    msg = Timesync.new_cmd() |> Timesync.json()

    # publish it!
    res = publish(msg)

    log && Logger.info(fn -> "published timesync #{inspect(res)}" end)

    opts = %{opts | loops: opts.loops - 1}

    cond do
      single ->
        :ok

      forever or loops - 1 > 0 ->
        :timer.sleep(ms(frequency))
        run(opts)

      true ->
        :executed_requested_loops
    end
  end

  def send do
    run(%{single: true})
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
    %{}
    |> Map.put(:mtime, unix_now(:second))
    |> Map.put(:cmd, @timesync_cmd)
  end

  @doc ~S"""
  Generate JSON for a command

  ##Examples:
   iex> c = Command.Timesync.setswitch([%{p0: true}, %{p1: false}], "uuid")
   ...> json = Command.Timesync.json(c)
   ...> parsed_cmd = Jason.Parser.parse!(json, [keys: :atoms!,
                                          as: Command.Timesync])
   ...> parsed_cmd === Map.from_struct(c)
   true
  """
  def json(%{} = c) do
    Jason.encode!(c)
  end
end
