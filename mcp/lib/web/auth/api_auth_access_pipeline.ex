defmodule Web.ApiAuthAccessPipeline do
  @moduledoc """
  """
  use Guardian.Plug.Pipeline, otp_app: :mcp

  plug(Guardian.Plug.VerifySession, claims: %{"typ" => "access"})
  plug(Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"})
  plug(Guardian.Plug.EnsureAuthenticated, handler: Web.ApiAuthErrorHandler)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end
