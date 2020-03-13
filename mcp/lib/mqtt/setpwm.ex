defmodule Mqtt.SetPulseWidth do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  @doc ~S"""
  Create a setswitch command with all map values required set to appropriate values

   ##Examples:
    iex> c = Mqtt.SetPulseWidth.new_cmd("device", 2048, "uuid")
    ...> %{cmd: "pwm", mtime: cmd_time} = c
    ...> (cmd_time > 0) and Map.has_key?(c, :duty)
    true
  """
  def new_cmd(device, duty, refid, opts \\ [])
      when is_binary(device) and is_integer(duty) and is_binary(refid) and
             is_list(opts),
      do: %{
        cmd: "pwm",
        mtime: TimeSupport.unix_now(:second),
        device: device,
        duty: duty,
        refid: refid,
        ack: Keyword.get(opts, :ack, true)
      }
end
