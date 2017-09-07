defmodule Bank.IExHelpers do
  def main_grow do
    Mcp.Chambers.get_status("main grow", :print)
  end
end
