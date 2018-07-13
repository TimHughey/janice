defmodule Repo.Migrations.AddSwitchGroup do
  @moduledoc false

  use Ecto.Migration

  def change do
    create_if_not_exists table(:switch_group) do
      add(:name, :string, size: 50, null: false)
      add(:description, :string, size: 100)
      add(:members, {:array, :string}, size: 2048)

      timestamps()
    end

    create_if_not_exists(index(:switch_group, [:name], unique: true))
  end
end
