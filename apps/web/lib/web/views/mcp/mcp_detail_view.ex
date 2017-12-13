defmodule Web.McpDetailView do
  use Web, :view

  use Timex
  alias Mcp.DevAlias
  alias Mcp.Sensor
  alias Mcp.Switch

  def render("index.json", %{mcp_details: mcp_details}) do
    %{data: render_many(mcp_details, Web.McpDetailView, "mcp_detail.json"),
      items: Enum.count(mcp_details),
      mtime: Timex.local |> Timex.to_unix}
  end

  def render("mcp_detail.json", %{mcp_detail: %DevAlias{} = da}) do
    tz = Timezone.local
    last_seen_secs = humanize_secs(da.last_seen_at)
    last_seen_at = Timezone.convert(da.last_seen_at, tz) |>
                    Timex.format!("{UNIX}")

    %{type: "dev_alias",
      id: da.id,
      friendly_name: da.friendly_name,
      device: da.device,
      description: da.description,
      last_seen_secs: last_seen_secs,
      last_seen_at: last_seen_at}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %{a: %DevAlias{} = da, s: %Switch{} = s}}) do

    %{type: "switch",
      id: da.id,
      friendly_name: da.friendly_name,
      device: da.device,
      enabled: s.enabled,
      description: da.description,
      dev_latency: s.dev_latency,
      last_cmd_secs: humanize_secs(s.last_cmd_at),
      last_seen_secs: humanize_secs(s.last_seen_at),
      state: Switch.get_state(da.friendly_name)}
  end

  def render("mcp_detail.json",
             %{mcp_detail: %{a: %DevAlias{} = da, s: %Sensor{} = s}}) do

    %{type: "sensor",
      id: da.id,
      friendly_name: da.friendly_name,
      device: da.device,
      description: da.description,
      last_seen_secs: humanize_secs(s.last_seen_at),
      reading_secs: humanize_secs(s.reading_at),
      celsius: s.temperature.tc}
  end

  defp humanize_secs(%DateTime{} = dt) do
    Timex.diff(Timex.now(), dt, :seconds) # |> humanize_secs
  end
end
