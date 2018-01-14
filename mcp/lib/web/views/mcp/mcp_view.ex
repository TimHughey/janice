defmodule Web.McpView do
  use Web, :view

  def dropdown_items(profiles) do
    items = for p <- profiles do
      link(p, to: "#", class: "dropdown-item") |> safe_to_string()
    end

    Enum.join(items, "\n") |> raw()
  end
end
