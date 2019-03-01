defmodule Repo.Migrations.AddMcrTable do
  use Ecto.Migration

  def current_time do
    fragment(~s/(now() at time zone 'utc')/)
  end

  def change do
    create_if_not_exists table(:remote) do
      add(:host, :string, size: 15, null: false)
      add(:name, :string, size: 25, null: false)
      add(:hw, :string, size: 10, null: false)
      add(:firmware_vsn, :string, size: 7, null: false, default: "0000000")
      add(:last_start_at, :utc_datetime, null: false, default: current_time())
      add(:last_seen_at, :utc_datetime, null: false, default: current_time())

      timestamps()
    end

    create_if_not_exists(index(:remote, [:host], unique: true))
    create_if_not_exists(index(:remote, [:name], unique: true))
  end
end
