defmodule Mcp.DevAlias do

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema
alias Ecto.Changeset

alias Mcp.{Repo,DevAlias}

schema "mcp_devaliases" do
  field :dev_id
  field :alias
  field :description

  timestamps usec: true
end

def alias(dev_id) when is_binary(dev_id) do
  Repo.get_by(DevAlias, [dev_id: dev_id])
end

def persist_and_check(%DevAlias{} = d) do
  d |> Repo.insert_or_update()
end

defp load_or_new(%DevAlias{} = d) do
  by_opts = [dev_id: d.dev_id]
  loaded = Repo.get_by(DevAlias, by_opts)
  load_or_new(loaded, d)
end
defp load_or_new(%DevAlias{} = loaded, %DevAlias{} = _new), do: loaded
defp load_or_new(:nil, %DevAlias{} = new), do: new

end
