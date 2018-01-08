defmodule Web.McpView do
  use Web, :view

  def friendly_names(dev_aliases) do
#    dev_aliases |>
#      Enum.map(fn(item) -> Map.from_struct(item) |>
#      Map.get(:friendly_name) end)
    dev_aliases
  end

  def dropdown_items(profiles) do
    items = for p <- profiles do
      ~S(<a class="dropdown-item" href="#">) <>
      "#{p}" <>
      ~S(</a>)
    end

    Enum.join(items, "\n")
  end
end
