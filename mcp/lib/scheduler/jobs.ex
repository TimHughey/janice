defmodule Janice.Jobs do
  @moduledoc false
  require Logger

  def purge_readings(opts) when is_list(opts), do: Sensor.purge_readings(opts)

  def touch_file do
    System.cmd("touch", ["/tmp/janice-every-minute"])
  end

  def touch_file(filename) when is_binary(filename) do
    System.cmd("touch", [filename])
  end
end
