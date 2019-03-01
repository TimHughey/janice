defmodule Repo.Migrations.AddMessages do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:message) do
      add :direction, :string, size: 15, null: false
      add :payload, :text
      add :dropped, :boolean, null: false, default: false

      timestamps()
    end
  end
end
