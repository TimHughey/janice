defmodule Mcp.DevAliasTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Mcp.DevAlias

  alias Mcp.DevAlias

  setup_all do
    DevAlias.add(%DevAlias{friendly_name: "relhum",
                           device: "i2c/F8F005F73FFF.01.sht31",
                           description: "test relative humidity"})

   DevAlias.add(%DevAlias{friendly_name: "temp_probe1",
                          device: "ds/28FFA442711FFF",
                          description: "test temp probe"})
    :ok
  end
end
