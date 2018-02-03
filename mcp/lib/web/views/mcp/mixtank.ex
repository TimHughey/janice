defmodule Web.MixtankView do
  use Web, :view

  require Logger
  use Timex

  def render("all.json", %{all: list}) do
    %{all: list}
  end
end
