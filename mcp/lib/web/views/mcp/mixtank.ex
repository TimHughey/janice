defmodule Web.MixtankView do
  use Web, :view

  require Logger
  use Timex

  def render("index.json", params) do
    %{mixtank: "good"}
  end

  def render("all.json", %{all: list}) do
    %{all: list}
  end

end
