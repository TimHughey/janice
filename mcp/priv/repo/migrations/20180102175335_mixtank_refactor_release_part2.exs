defmodule Repo.Migrations.MixtankRefactorReleasePart2 do
  @moduledoc """
  """
  require Logger
  use Ecto.Migration

  import Seed.Dutycycles
  import Seed.Mixtanks
  import Repo, only: [update_all: 2]
  import Ecto.Query, only: [from: 2]

  def change do
    result =
      SwitchState.change_name("unused1",
                              "display_tank_replenish",
                              "rodi water to replenish evaporation")

    Logger.info fn -> "switch state name change: #{inspect(result)}" end

    from(dc in Dutycycle,
      update: [set: [enable: false]]) |> update_all([])

    dutycycles(Mix.env) |>
      Enum.each(fn(x) -> Logger.info("seeding dutycycle [#{x.name}]")
                           Dutycycle.add(x) end)

    mixtanks(Mix.env) |>
      Enum.each(fn(x) -> Logger.info("seeding mixtank [#{x.name}]")
                           Mixtank.add(x) end)

  end
end
