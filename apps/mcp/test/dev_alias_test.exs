defmodule Mcp.McrAliasTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Mcp.McrAlias

  alias Mcp.McrAlias

  setup_all do
    McrAlias.add(%McrAlias{friendly_name: "relhum",
                           device: "i2c/f8f005f73fff.01.sht31",
                           description: "test relative humidity"})

   McrAlias.add(%McrAlias{friendly_name: "temp_probe1",
                          device: "ds/28ffa442711ff",
                          description: "test temp probe"})
    :ok
  end
end
