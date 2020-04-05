defmodule Fact.Influx do
  @moduledoc false

  use Instream.Connection, otp_app: :mcp

  def shards(db) do
    Fact.Influx.execute("show shards")
    |> Map.get(:results)
    |> hd()
    |> Map.get(:series)
    |> Enum.find(fn x -> Map.get(x, :name, db) == db end)
  end
end
