defmodule Repo.Migrations.MessageSaveIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:message, [:inserted_at])
  end
end
