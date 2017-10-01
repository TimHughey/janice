defmodule Mcp.GenServerTest do
  use ExUnit.Case, async: true 

  defmodule Local do
    use Mcp.GenServer
  
  end

  test "can the server_name macro find the a local name" do
    val = Local.server_name()
    assert val == Elixir.Mcp.GenServerTest.Local 
  end

  test "can the config macro retrieve a string?" do
    val = Local.config(:yesterday)

    assert val == "tomorrow"
  end

  defmodule Global do
    use Mcp.GenServer
  end      


  test "can the server_name macro find a global name?" do
    {atom, name} = Global.server_name()

    assert atom == :global and name == Mcp.GenServerTest.Global 
  end

  test "the truth" do
    assert 1 + 1 == 2
  end
end
