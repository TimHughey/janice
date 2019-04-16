defmodule Repo.Migrations.IncreaseRemoteVersionLength do
  use Ecto.Migration

  def change do
    alter table(:remote) do
      modify(:firmware_vsn, :text, size: 32)
      add(:project_name, :text, size: 32)
      add(:idf_vsn, :text, size: 32)
      add(:app_elf_sha256, :text, size: 32)
      add(:build_date, :text, size: 16)
      add(:build_time, :text, size: 16)
      add(:magic_word, :integer)
      add(:secure_vsn, :integer)
    end
  end
end
