defmodule ApiWeb.McpView do
  use ApiWeb, :view

  def friendly_names(dev_aliases) do
#    dev_aliases |>
#      Enum.map(fn(item) -> Map.from_struct(item) |> Map.get(:friendly_name) end)

    dev_aliases
  end
end
