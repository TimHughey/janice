defmodule Web.Local.Helpers do
  @moduledoc """

  """

  def resp_mapper(src_map, keys) when is_list(keys) do
    for {sk, dk} <- keys do
      {dk, Map.get(src_map, sk)}
    end
    |> Enum.into(%{})
  end
end
