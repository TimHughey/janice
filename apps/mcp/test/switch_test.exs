defmodule SwitchTest do
  alias Mcp.Switch
  use ExUnit.Case, async: false

#  test "can purge all switches?" do
#    count = Switch.auto_populate
#    
#    assert Switch.purge_all(:for_real) == count
#  end

  test "are there any switches" do
   assert Switch.any_switches?()
  end 

#  test "are there zero switches?" do
#    _all = Switch.purge_all(:for_real)
#    assert Switch.any_switches?() == :false 
#  end

  test "can auto populate switches" do
    count = 
      case Switch.any_switches?() do
        :true  -> 1
        :false -> Switch.auto_populate()
      end  

    assert count > 0
  end

  def random_name() do
    :crypto.strong_rand_bytes(10) |> Base.hex_encode32
  end
end
