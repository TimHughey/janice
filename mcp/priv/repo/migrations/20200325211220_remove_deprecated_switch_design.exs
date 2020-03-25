defmodule Repo.Migrations.RemoveDeprecatedSwitchDesign do
  use Ecto.Migration

  def change do
    drop_if_exists(table("switch_state"))
    drop_if_exists(table("switch_group"))
    drop_if_exists(table("switch_cmd"))
    drop_if_exists(table("switch"))
  end
end
