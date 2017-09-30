defmodule Mcp.McrAliasTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Mcp.McrAlias

  alias Mcp.McrAlias

  setup_all do
    McrAlias.add(%McrAlias{friendly_name: "relhum",
                           device: "i2c/f8f005f73b53.01.sht31",
                           description: "basement relative humidity"})
    :ok
  end
end
