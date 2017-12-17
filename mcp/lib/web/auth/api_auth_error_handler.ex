defmodule Web.ApiAuthErrorHandler do
  @moduledoc """
  """
  require Logger
  use Web, :controller
  import Plug.Conn

  def auth_error(conn, {type, reason}, _opts) do
    # Logger.info fn -> inspect(conn) end
    Logger.warn fn -> "unauthenticated request for #{conn.request_path}" end

    body =
      Poison.encode!(%{data: "not authenticated",
                       type: "#{inspect(type)}",
                       reason: "#{inspect(reason)}"})

    send_resp(conn, 401, body)
  end
end
