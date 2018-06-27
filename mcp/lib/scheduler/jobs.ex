defmodule Janice.Jobs do
  @moduledoc false
  require Logger

  def germination(pos) when is_boolean(pos) do
    sw = "germination_light"
    curr = SwitchState.state(sw)

    if curr == pos do
      Logger.debug(fn -> "#{sw} position correct" end)
    else
      SwitchState.state(sw, position: pos, lazy: true)
      Logger.info(fn -> "#{sw} position set to #{inspect(pos)}" end)
    end
  end

  def touch_file do
    System.cmd("touch", ["/tmp/janice-every-minute"])
  end

  def touch_file(filename) when is_binary(filename) do
    System.cmd("touch", [filename])
  end
end
