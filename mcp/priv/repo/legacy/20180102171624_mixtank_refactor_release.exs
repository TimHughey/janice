defmodule Repo.Migrations.MixtankRefactorRelease do
  @moduledoc """
  """
  use Ecto.Migration

  def change do
    alter table(:dutycycle) do
      add :log, :boolean, default: false
    end
  end
end
