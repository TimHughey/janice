defmodule Seedlings do
  @moduledoc false

  use Switch

  def lights(:day),
    do: sw_position("germination lights", position: true, ensure: true)

  def lights(:night),
    do: sw_position("germination lights", position: false, ensure: true)
end
