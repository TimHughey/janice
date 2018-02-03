defmodule Seed.Dutycycles do
  @moduledoc """
  """
  def dutycycles(env) when env in [:dev, :test] do
    [
      %Dutycycle{
        name: "duty 1",
        enable: true,
        comment: "duty 1 non-prod",
        device: "sw1",
        profiles: [
          %Dutycycle.Profile{name: "fast", active: true, run_ms: 60_000, idle_ms: 600_000},
          %Dutycycle.Profile{name: "slow", run_ms: 120_000, idle_ms: 240_000}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "duty 2",
        comment: "duty 2 non-prod",
        device: "sw2",
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 2000, idle_ms: 2000},
          %Dutycycle.Profile{name: "slow", run_ms: 20_000, idle_ms: 20_000}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "dev mixtank1 pump",
        comment: "pump for mixtank",
        device: "sw3",
        profiles: [
          %Dutycycle.Profile{name: "high", run_ms: 120_000, idle_ms: 60_000},
          %Dutycycle.Profile{name: "low", run_ms: 20_000, idle_ms: 20_000},
          %Dutycycle.Profile{name: "on", run_ms: 60_000, idle_ms: 0}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "dev mixtank1 air",
        comment: "air for mixtank",
        device: "sw4",
        profiles: [
          %Dutycycle.Profile{name: "high", run_ms: 120_000, idle_ms: 60_000},
          %Dutycycle.Profile{name: "low", run_ms: 20_000, idle_ms: 20_000},
          %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 60_000}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "dev mixtank1 heater",
        comment: "heater for mixtank",
        device: "sw5",
        profiles: [
          %Dutycycle.Profile{name: "on", run_ms: 120_000, idle_ms: 0},
          %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 120_000}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "dev mixtank1 rodi fill",
        comment: "rodi fill for mixtank",
        device: "sw6",
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 120_000, idle_ms: 60_000},
          %Dutycycle.Profile{name: "slow", run_ms: 60_000, idle_ms: 120_000},
          %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 60_000}
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "dev mixtank1 replenish",
        comment: "replenish for sump (as part of mixtank1)",
        device: "sw7",
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 120_000, idle_ms: 60_000},
          %Dutycycle.Profile{name: "slow", run_ms: 60_000, idle_ms: 120_000},
          %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 60_000}
        ],
        state: %Dutycycle.State{}
      }
    ]
  end

  def dutycycles(:prod) do
    [
      %Dutycycle{
        name: "reefwater mix pump",
        comment: "pump for mixtank",
        device: "mixtank_pump",
        profiles: [
          %Dutycycle.Profile{name: "high", run_ms: 45 * 60 * 1000, idle_ms: 60_000},
          %Dutycycle.Profile{name: "low", run_ms: 15 * 60 * 1000, idle_ms: 30 * 60 * 1000},
          on_profile()
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "reefwater mix air",
        comment: "air for mixtank",
        device: "mixtank_air",
        profiles: [
          %Dutycycle.Profile{name: "high", run_ms: 10 * 60 * 1000, idle_ms: 5 * 60 * 1000},
          %Dutycycle.Profile{name: "low", run_ms: 3 * 60 * 100, idle_ms: 10 * 60 * 1000},
          off_profile()
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "reefwater mix heater",
        comment: "heater for mixtank",
        device: "mixtank_heater",
        profiles: [on_profile(), off_profile()],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "reefwater rodi fill",
        comment: "rodi fill for mixtank",
        device: "reefmix_rodi_valve",
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 10 * 60 * 1000, idle_ms: 3 * 60 * 1000},
          %Dutycycle.Profile{name: "slow", run_ms: 3 * 60 * 1000, idle_ms: 15 * 60 * 1000},
          off_profile()
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "display tank replenish",
        comment: "replenish for sump (as part of reefwater mix)",
        device: "display_tank_replenish",
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 10 * 60 * 1000, idle_ms: 5 * 60 * 1000},
          %Dutycycle.Profile{name: "slow", run_ms: 3 * 60 * 1000, idle_ms: 15 * 60 * 1000},
          off_profile()
        ],
        state: %Dutycycle.State{}
      }
    ]
  end

  # [%Dutycycle{name: "sump vent",
  #    description: "sump vent",
  #    enable: false, device_sw: "sump_vent",
  #    run_ms: 20 * 60 * 1000, idle_ms: 2 * 60 * 1000},
  #  %Dutycycle{name: "basement circulation",
  #    description: "basement circulation fan",
  #    enable: false, device_sw: "basement_fan",
  #    run_ms: 15 * 60 * 1000, idle_ms: 60 * 1000},

  def off_profile do
    %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 600_000}
  end

  def on_profile do
    %Dutycycle.Profile{name: "on", run_ms: 600_000, idle_ms: 0}
  end
end
