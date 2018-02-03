defmodule Web.UserFromAuth do
  @moduledoc """
  Retrieve the user information from an auth request
  """
  require Logger
  require Poison

  alias Ueberauth.Auth

  def find_or_create(%Auth{provider: :identity} = auth) do
    Logger.info(fn -> "identity provided validates password" end)

    case validate_pass(auth) do
      :ok ->
        {:ok, basic_info(auth)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def find_or_create(%Auth{provider: :github, info: info} = auth) do
    case authorized_user(info) do
      :ok -> {:ok, basic_info(auth)}
      {:error, reason} -> {:error, reason}
    end
  end

  def find_or_create(%Auth{} = auth) do
    {:ok, basic_info(auth)}
  end

  defp authorized_user(%Auth.Info{nickname: nickname})
       when nickname in ["TimHughey"] do
    :ok
  end

  defp authorized_user(%Auth.Info{nickname: nickname}) do
    {:error, "#{nickname} not authorized"}
  end

  # github does it this way
  defp avatar_from_auth(%{info: %{urls: %{avatar_url: image}}}), do: image

  # facebook does it this way
  defp avatar_from_auth(%{info: %{image: image}}), do: image

  # default case if nothing matches
  defp avatar_from_auth(auth) do
    Logger.warn(auth.provider <> " needs to find an avatar URL!")
    Logger.debug(Poison.encode!(auth))
    nil
  end

  defp basic_info(auth) do
    %{
      id: auth.uid,
      name: name_from_auth(auth),
      nickname: auth.info.nickname,
      avatar: avatar_from_auth(auth)
    }
  end

  defp name_from_auth(auth) do
    if auth.info.name do
      auth.info.name
    else
      name =
        [auth.info.first_name, auth.info.last_name]
        |> Enum.filter(&(&1 != nil and &1 != ""))

      if Enum.empty?(name),
        do: auth.info.nickname,
        else: Enum.join(name, " ")
    end
  end

  defp validate_pass(%{credentials: %{other: %{password: pass}}, info: %{nickname: nickname}})
       when is_nil(pass) or pass == "foo" do
    Logger.info(fn -> "#{nickname} password validated" end)
    :ok
  end

  defp validate_pass(%{credentials: %{other: %{password: _pass}}, info: %{nickname: nickname}}) do
    Logger.info(fn -> "#{nickname} password incorrect" end)
    {:error, "Invalid password"}
  end

  defp validate_pass(_), do: {:error, "Default catch for pw check!"}
end
