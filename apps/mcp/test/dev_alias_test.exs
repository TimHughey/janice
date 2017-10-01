defmodule Mcp.McrAliasTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Mcp.McrAlias

  alias Mcp.McrAlias

  setup_all do
    McrAlias.add(%McrAlias{friendly_name: "relhum",
                           device: "i2c/f8f005f73b53.01.sht31",
                           description: "basement relative humidity"})

   McrAlias.add(%McrAlias{friendly_name: "temp_probe1",
                          device: "ds/28ffa442711604",
                          description: "testing DS1820 temp probe"})
    :ok
  end
end
