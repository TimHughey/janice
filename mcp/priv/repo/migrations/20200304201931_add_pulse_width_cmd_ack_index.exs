defmodule Repo.Migrations.AddPulseWidthCmdAckIndex do
  @moduledoc false

  use Ecto.Migration

  def change do
    drop_if_exists(index(:pwm_cmd, [:acked]))

    create_if_not_exists(index(:pwm_cmd, [:acked]))
  end
end
