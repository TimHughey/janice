defmodule Web.Guardian do
  @moduledoc """
  """
  use Guardian, otp_app: :mcp

  def subject_for_token(resource, _claims), do: {:ok, to_string(resource.id)}

  def resource_from_claims(claims) do
    # {:ok, resource} or {:error, reason}
    find_me_a_resource(claims["sub"])
  end

  defp find_me_a_resource(sub) do
    {:ok, sub}
  end

  # def subject_for_token(resource, _claims) do
  #   # You can use any value for the subject of your token but
  #   # it should be useful in retrieving the resource later, see
  #   # how it being used on `resource_from_claims/1` function.
  #   # A unique `id` is a good subject, a non-unique email address
  #   # is a poor subject.
  #   # sub = to_string(resource.id)
  #   sub = to_string(resource)
  #   {:ok, sub}
  # end
  # def subject_for_token(_, _) do
  #   {:error, :reason_for_error}
  # end
  #
  # def resource_from_claims(claims) do
  #   # Here we'll look up our resource from the claims, the subject can be
  #   # found in the `"sub"` key. In `above subject_for_token/2` we returned
  #   # the resource id so here we'll rely on that to look it up.
  #   id = claims["sub"]
  #   # resource = MyApp.get_resource_by_id(id)
  #   resource = id
  #   {:ok,  resource}
  # end
  # def resource_from_claims(_claims) do
  #   {:error, :reason_for_error}
  # end
end
