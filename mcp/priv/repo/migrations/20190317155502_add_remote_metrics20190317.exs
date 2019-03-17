defmodule Repo.Migrations.AddRemoteMetrics20190317 do
  use Ecto.Migration

  def change do
    alter table("remote") do
      add(:ap_rssi, :integer, default: 0)
      add(:ap_pri_chan, :integer, default: 0)
      add(:ap_sec_chan, :integer, default: 0)
      add(:heap_free, :integer, default: 0)
      add(:heap_min, :integer, default: 0)
    end
  end
end
