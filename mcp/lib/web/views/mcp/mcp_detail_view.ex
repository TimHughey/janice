defmodule Web.McpDetailView do
  use Web, :view

  use Timex

  def render("index.json", %{mcp_details: mcp_details}) do
    %{data: render_many(mcp_details, Web.McpDetailView, "mcp_detail.json"),
      items: Enum.count(mcp_details),
      mtime: Timex.local |> Timex.to_unix}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %SwitchState{} = ss}) do

    %{type: "switch",
      id: ss.id,
      friendly_name: ss.name,
      device: ss.switch.device,
      enabled: ss.switch.enabled,
      description: ss.description,
      dev_latency: ss.switch.dev_latency,
      # rt_latency: ss.switch.rt_latency |> hd(),
      last_cmd_secs: humanize_secs(ss.switch.last_cmd_at),
      last_seen_secs: humanize_secs(ss.switch.last_seen_at),
      state: ss.state}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %Sensor{} = s}) do

    %{type: "sensor",
      id: s.id,
      friendly_name: s.name,
      device: s.device,
      description: s.description,
      dev_latency: s.dev_latency,
      last_seen_secs: humanize_secs(s.last_seen_at),
      reading_secs: humanize_secs(s.reading_at),
      celsius: s.temperature.tc}
  end

  defp humanize_secs(%DateTime{} = dt) do
    Timex.diff(Timex.now(), dt, :seconds) # |> humanize_secs
  end
end
