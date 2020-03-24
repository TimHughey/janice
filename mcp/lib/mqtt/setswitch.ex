defmodule Mqtt.SetSwitch do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  @setswitch_cmd "set.switch"

  def new_cmd(device, states, refid, opts \\ [])

  @doc ~S"""
  Create a setswitch command with all map values required set to appropriate values

   ##Examples:
    iex> new_states = [%{"pio": 0, "state": true}, %{"pio": 1, "state": false}]
    ...> c = Mqtt.SetSwitch.new_cmd.setswitch("device", new_states, "uuid")
    ...> %Mqtt.SetSwitch{cmd: "setswitch", mtime: cmd_time} = c
    ...> (cmd_time > 0) and Map.has_key?(c, :states)
    true
  """

  def new_cmd(device, states, refid, opts)
      when is_binary(device) and is_list(states) and is_binary(refid) and
             is_list(opts),
      do: %{
        cmd: @setswitch_cmd,
        mtime: TimeSupport.unix_now(:second),
        switch: device,
        states: states,
        refid: refid,
        ack: Keyword.get(opts, :ack, true)
      }

  # if a single state map is passed wrap it in a list and call new_cmd/4 again
  def new_cmd(device, state, refid, opts)
      when is_map(state),
      do: new_cmd(device, [state], refid, opts)
end
