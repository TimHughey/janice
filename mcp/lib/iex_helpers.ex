defmodule Mcp.IExHelpers do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  def server_state(mod), do: :sys.get_state(mod)
  def server_status(mod), do: :sys.get_status(mod)

  def server_pid(mod) do
    {:status, pid, _} = :sys.get_status(mod)
    pid
  end

  def make_mtime_current(json) do
    mtime = TimeSupport.unix_now(:second)

    Jason.decode!(json, keys: :atoms)
    |> Map.put(:mtime, mtime)
    |> Jason.encode!()
  end

  def change_device(json, device) do
    Jason.decode!(json, keys: :atoms)
    |> Map.put(:device, device)
    |> Jason.encode!()
  end

  def change_temp(json, device, tf) do
    Jason.decode!(json, keys: :atoms)
    |> Map.put(:device, device)
    |> Map.put(:tf, tf)
    |> Map.put(:tc, (tf - 32.0) / 1.8)
    |> Jason.encode!()
  end

  def tsensor_test do
    tsensor_test("ds/test_device4")
  end

  def tsensor_test(device) do
    json = ~s|{"version":"aac8961",
            "host":"mcr.f8f005e944e2",
            "device":"ds/test_device4",
            "mtime":1512862674,
            "type":"temp",
            "tc":17.25,
            "tf":63.05}|

    make_mtime_current(json)
    |> change_device(device)
    |> Mqtt.InboundMessage.process()
  end

  def tsensor_test(device, tf) do
    json = ~s|{"version":"aac8961",
            "host":"mcr.f8f005e944e2",
            "device":"ds/test_device4",
            "mtime":1512862674,
            "type":"temp",
            "tc":17.25,
            "tf":63.05}|

    make_mtime_current(json)
    |> change_device(device)
    |> change_temp(device, tf)
    |> Mqtt.InboundMessage.process()
  end

  def rsensor_test do
    rsensor_test("i2c/relhum_device4")
  end

  def rsensor_test(device) do
    json = ~s|{"version":"aac8961",
            "host":"mcr.f8f005e944e2",
            "device":"i2c/relhum_device4",
            "mtime":1512862674,
            "type":"temp",
            "tc":17.25,
            "tf":63.05,
            "rh":45.32}|

    make_mtime_current(json)
    |> change_device(device)
    |> Mqtt.InboundMessage.process()
  end

  def switch_json do
    ~s|{"version":"aac8961",
      "host":"mcr.f8f005e755da",
      "device":"ds/12838421000000",
      "mtime":1512862673,
      "type":"switch",
      "pio_count":2,
      "states":[{"pio":0,"state":true},{"pio":1,"state":true}]}|
  end

  def switch_test do
    switch_test("ds/2pos1")
  end

  def switch_test(device) do
    switch_json()
    |> make_mtime_current()
    |> change_device(device)
    |> Mqtt.InboundMessage.process()
  end

  def ack_all_cmds do
    SwitchCmd.unacked() |> ack_a_cmd()
  end

  def ack_a_cmd, do: SwitchCmd.unacked() |> hd()
  def ack_a_cmd([]), do: :ok

  def ack_a_cmd(cmds) when is_list(cmds) do
    ack_a_cmd(hd(cmds))
    ack_a_cmd(tl(cmds))
  end

  def ack_a_cmd(%SwitchCmd{} = cmd) do
    states =
      Enum.map(cmd.switch.states, fn x -> %{pio: x.pio, state: x.state} end)

    pio_count = Enum.count(states)

    %{
      version: "aac8961",
      host: "mcr.f8f005e755da",
      device: cmd.switch.device,
      mtime: TimeSupport.unix_now(:second),
      type: "switch",
      pio_count: pio_count,
      states: states,
      refid: cmd.refid,
      cmdack: true
    }
    |> Jason.encode!()
    |> Mqtt.InboundMessage.process()
  end

  def big_switch_state_test do
    switch_state_test(["sw1", "sw2", "sw3"], 10, [true, true, true, false, true])
  end

  def switch_state_test, do: switch_state_test(["sw1"], 10, [true, false])

  def switch_state_test(name)
      when is_binary(name),
      do: switch_state_test([name], 10, [true, false])

  def switch_state_test(name, count, states)
      when is_binary(name),
      do: switch_state_test([name], count, states)

  def switch_state_test(names, count, states) when is_list(states) do
    {elapsed, result} =
      :timer.tc(fn ->
        for name <- names,
            _i <- 0..count,
            j <- states do
          SwitchState.state(name, j)
          ack_a_cmd()
        end
      end)

    Logger.info(fn ->
      "switch_state_test() count: #{Enum.count(result)} " <>
        "switches: #{inspect(names)} " <> "elapsed microsecs: #{elapsed}"
    end)

    :ok
  end

  def observer do
    :observer.start()
    Node.connect(:"prod-mcp@jophiel.wisslanding.com")
  end
end

## defmodule end
