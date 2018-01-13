defmodule Web.McpDetailView do
  use Web, :view

  use Timex

  def render("index.json", %{mcp_details: mcp_details}) do
    %{data: render_many(mcp_details, Web.McpDetailView, "mcp_detail.json"),
      items: Enum.count(mcp_details),
      mtime: Timex.local |> Timex.to_unix}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %{type: "switch"} = ss}) do

    %{type: "switch",
      id: ss.id,
      name: ss.name,
      device: ss.device,
      enabled: ss.enabled,
      description: ss.description,
      dev_latency: ss.dev_latency,
      rt_latency: ss.rt_latency,
      last_cmd_secs: humanize_secs(ss.last_cmd_at),
      last_seen_secs: humanize_secs(ss.last_seen_at),
      state: ss.state}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %Sensor{} = s}) do

    %{type: "sensor",
      id: s.id,
      name: s.name,
      device: s.device,
      description: s.description,
      dev_latency: s.dev_latency,
      last_seen_secs: humanize_secs(s.last_seen_at),
      reading_secs: humanize_secs(s.reading_at),
      celsius: s.temperature.tc}
  end

  defp humanize_secs(nil), do: 0

  defp humanize_secs(%DateTime{} = dt) do
    Timex.diff(Timex.now(), dt, :seconds) # |> humanize_secs
  end
end
