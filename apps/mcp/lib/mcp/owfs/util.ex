defmodule Mcp.Owfs.Util do
  @moduledoc """
    MCP Owfs Utility functions
  """
  require Logger

  #alias __MODULE__
  alias Mcp.Owfs

  def owfs_path, do: Owfs.config(:path)
  def bus_list do
    raw = raw_bus_list()
    Enum.filter(raw, &Regex.match?(~r/bus./, &1))
  end
  defp raw_bus_list do
    case File.ls(owfs_path()) do
      {:ok, raw}         -> raw
      {:error, _ignored} -> []
    end
  end
end
