defmodule Janice.Common.DB do
  @moduledoc false
  use Timex

  def name_regex, do: ~r'^[\\~\w]+[\w\\ \\/\\:\\.\\_\\-]{1,}[\w]$'
end
