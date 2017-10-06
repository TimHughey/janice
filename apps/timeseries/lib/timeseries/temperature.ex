defmodule Timeseries.Temperature do
  @moduledoc """
  """
  use Instream.Series

  series do
    database    "mcp_repo"
    measurement "temp_F"

    tag :remote_host, default: "unknown-host"
    tag :device, default: "unknown-device"
    tag :friendly_name, default: "unknown-friendly"
    tag :env, default: "dev"

    field :val
  end
end
