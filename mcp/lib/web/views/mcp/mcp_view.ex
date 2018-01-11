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
      link(p, to: "#", class: "dropdown-item") |> safe_to_string()
    end

    Enum.join(items, "\n") |> raw()
  end
end
