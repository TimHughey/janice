defmodule Mcp.Repo.Migrations.AddRelHumFreqAndDur do
  use Ecto.Migration

  def change do
    alter table(:chambers) do
      add :relh_freq_ms, :integer, null: false, default: 20*60*1000
      add :relh_dur_ms, :integer, null: false, default: 2*60*1000
    end
  end
end
