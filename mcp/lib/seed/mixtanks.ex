defmodule Seed.Mixtanks do
  @moduledoc """
  """

  alias Mixtank.Profile
  alias Mixtank.State

  def mixtanks(env) when env in [:dev, :test] do
    [
      %Mixtank{
        name: "reefwater",
        comment: "mixtank for new reefwater)",
        enable: true,
        sensor: "test temperature 1",
        ref_sensor: "test temperature 2",
        pump: "dev mixtank1 pump",
        air: "dev mixtank1 air",
        heater: "dev mixtank1 heater",
        fill: "dev mixtank1 rodi fill",
        replenish: "dev mixtank1 replenish",
        state: %State{},
        profiles: [
          %Profile{
            name: "minimal",
            active: true,
            pump: "low",
            air: "low",
            fill: "off",
            replenish: "fast",
            temp_diff: -5
          },
          %Profile{
            name: "fill overnight",
            active: false,
            pump: "high",
            air: "off",
            fill: "fast",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "fill daytime",
            active: false,
            pump: "high",
            air: "off",
            fill: "slow",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "mix",
            active: false,
            pump: "high",
            air: "high",
            fill: "off",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "change",
            active: false,
            pump: "on",
            air: "off",
            fill: "off",
            replenish: "off",
            temp_diff: 0
          }
        ]
      }
    ]
  end

  def mixtanks(:prod) do
    [
      %Mixtank{
        name: "reefwater",
        comment: "mixtank for new reefwater)",
        enable: true,
        sensor: "mixtank",
        ref_sensor: "display_tank",
        pump: "reefwater mix pump",
        air: "reefwater mix air",
        heater: "reefwater mix heater",
        fill: "reefwater rodi fill",
        replenish: "display tank replenish",
        state: %State{},
        profiles: [
          %Profile{
            name: "minimal",
            active: true,
            pump: "low",
            air: "low",
            fill: "off",
            replenish: "fast",
            temp_diff: -5
          },
          %Profile{
            name: "fill overnight",
            active: false,
            pump: "high",
            air: "off",
            fill: "fast",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "fill daytime",
            active: false,
            pump: "high",
            air: "off",
            fill: "slow",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "mix",
            active: false,
            pump: "high",
            air: "high",
            fill: "off",
            replenish: "fast",
            temp_diff: 0
          },
          %Profile{
            name: "change",
            active: false,
            pump: "on",
            air: "off",
            fill: "off",
            replenish: "off",
            temp_diff: 0
          }
        ]
      }
    ]
  end
end
