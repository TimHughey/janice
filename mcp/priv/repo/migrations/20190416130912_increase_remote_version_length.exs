defmodule Repo.Migrations.IncreaseRemoteVersionLength do
  use Ecto.Migration

  def change do
    alter table(:remote) do
      modify(:firmware_vsn, :string, size: 32)
      add(:project_name, :string, size: 32)
      add(:idf_vsn, :string, size: 32)
      add(:app_elf_sha256, :string, size: 32)
      add(:build_date, :string, size: 16)
      add(:build_time, :string, size: 16)
      add(:magic_word, :integer)
      add(:secure_vsn, :integer)
    end
  end
end
