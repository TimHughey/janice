defmodule Repo.Migrations.ChangeMessageSaveToHandleMsgPack do
  @moduledoc false

  use Ecto.Migration

  def change do
    drop_if_exists(table(:message))

    create_if_not_exists table(:message) do
      add(:direction, :string, size: 15, null: false)
      add(:src_host, :text, null: false, default: " ")

      add(:msgpack, :binary,
        null: false,
        default: fragment("'\\000'")
      )

      add(:json, :text, null: false, default: " ")
      add(:dropped, :boolean, null: false, default: false)
      add(:keep_for_testing, :boolean, null: false, default: false)

      timestamps()
    end

    create_if_not_exists(index(:message, [:inserted_at]))
    create_if_not_exists(index(:message, [:keep_for_testing]))
  end
end
