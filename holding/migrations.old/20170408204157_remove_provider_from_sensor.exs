defmodule Mcp.Repo.Migrations.RemoveProviderFromSensor do
  @moduledoc """
  """

  use Ecto.Migration

  def change do
    alter table(:sensors) do
      remove :provider
    end
  end
end
