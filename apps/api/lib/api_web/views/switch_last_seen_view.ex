defmodule ApiWeb.SwitchesLastSeenView do
  use ApiWeb, :view

  alias Mcp.Switch

  def render("index.json", %{switches: switches}) do
    %{
      switches: Enum.map(switches, &switch_json/1)
    }
  end

  def switch_json(%Switch{} = sw) do
    %{
      id: sw.id,
      device: sw.device,
      last_seen: sw.last_seen_at
    } 
  end
end
