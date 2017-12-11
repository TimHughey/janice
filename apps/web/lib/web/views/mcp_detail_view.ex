defmodule Web.McpDetailView do
  use Web, :view

  use Timex
  alias Mcp.DevAlias

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
      friendly_name: da.friendly_name,
      device: da.device,
      description: da.description,
      last_seen_secs: last_seen_secs,
      last_seen_at: last_seen_at}
  end

  defp humanize_microsecs(us)
  when is_number(us) and us > 1000 do
    "#{Float.round(us / 1000.0, 2)} ms"
  end

  defp humanize_microsecs(us)
  when is_number(us) do
    "#{us} us"
  end

  defp humanize_microsecs(_), do: "-"

  defp humanize_secs(%DateTime{} = dt) do
    Timex.diff(Timex.now(), dt, :seconds) |> humanize_secs
  end

  # one (1) week: 604_800
  # one (1) day : 86,400
  # one (1) hour: 3_600

  defp humanize_secs(secs)
  when secs >= 604_800 do
    ">1 week"
  end

  defp humanize_secs(secs)
  when secs >= 86_400 do
    ">1 day"
  end

  defp humanize_secs(secs)
  when secs >= 3_600 do
    ">1 hr"
  end

  defp humanize_secs(secs)
  when secs >= 60 do
    ">1 min"
  end

  defp humanize_secs(secs) do
    "#{secs} secs"
  end
end
