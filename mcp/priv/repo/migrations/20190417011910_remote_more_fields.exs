defmodule Repo.Migrations.RemoteMoreFields do
  use Ecto.Migration

  def change do
    alter table(:remote) do
      modify(:magic_word, :string)
      modify(:app_elf_sha256, :string)
      add(:bssid, :string, default: "xx:xx:xx:xx:xx:xx")
    end
  end
end
