defmodule Web.McpDetailController do
  @moduledoc """
  """
  require Logger

  use Timex
  use Web, :controller

  def index(conn, %{"type" => "switches"} = _params) do
    # Logger.info fn -> inspect(params) end

    all_ss = SwitchState.all(:everything)
    last_cmds = SwitchCmd.last_cmds(100)

    switches = for ss <- all_ss do
      cmd = SwitchCmd.get_rt_latency(last_cmds, ss.name)

      %{id: ss.id,
          type: "switch",
          name: ss.name,
          device: ss.switch.device,
          enabled: ss.switch.enabled,
          description: ss.description,
          dev_latency: ss.switch.dev_latency,
          rt_latency: cmd.rt_latency,
          last_cmd_at: cmd.sent_at,
          last_seen_at: ss.switch.last_seen_at,
          state: ss.state}
    end

    render conn, "index.json", mcp_details: switches
  end

  def index(conn, %{"type" => "sensors"} = _params) do
    # Logger.info fn -> inspect(params) end
    # Logger.debug fn -> inspect(conn) end

    sensors = Sensor.all(:everything)

    render conn, "index.json", mcp_details: sensors
  end

end
