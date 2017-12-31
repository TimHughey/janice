defmodule Seed.Dutycycles do
  @moduledoc """
  """
def dutycycles(env) when env in [:dev, :test] do
  [%Dutycycle{name: "duty 1",
    enable: true,
    comment: "duty 1 non-prod",
    device: "sw5",
    profiles: [%Dutycycle.Profile{name: "fast",
            active: true,
            run_ms: 60_000, idle_ms: 600_000},
           %Dutycycle.Profile{name: "slow",
            run_ms: 120_000, idle_ms: 240_000}],
    state: %Dutycycle.State{}},
   %Dutycycle{name: "duty 2",
     comment: "duty 2 non-prod",
     device: "sw6",
     profiles: [%Dutycycle.Profile{name: "fast",
             run_ms: 2000, idle_ms: 2000},
            %Dutycycle.Profile{name: "slow",
             run_ms: 20_000, idle_ms: 20_000}],
     state: %Dutycycle.State{}},
   %Dutycycle{name: "duty 2",
     comment: "duty 2 non-prod",
     device: "duty_sw3",
     profiles: [%Dutycycle.Profile{name: "fast",
             run_ms: 2000, idle_ms: 2000},
            %Dutycycle.Profile{name: "slow",
             run_ms: 20_000, idle_ms: 20_000}],
     state: %Dutycycle.State{}}]
end

def dutycycles(:prod) do
  [%Dutycycle{name: "reefwater fill",
    enable: true,
    comment: "fill the reefwater mix barrel",
    device: "reefmix_rodi_valve",
    profiles: [%Dutycycle.Profile{name: "slow",
            active: true,
            run_ms: (15*60*1000), idle_ms: (5*60*1000)},
           %Dutycycle.Profile{name: "fast",
            run_ms: (10*60*1000), idle_ms: (60*1000)}],
    state: %Dutycycle.State{}}]

  # [%Dutycycle{name: "sump vent",
  #    description: "sump vent",
  #    enable: false, device_sw: "sump_vent",
  #    run_ms: 20 * 60 * 1000, idle_ms: 2 * 60 * 1000},
  #  %Dutycycle{name: "basement circulation",
  #    description: "basement circulation fan",
  #    enable: false, device_sw: "basement_fan",
  #    run_ms: 15 * 60 * 1000, idle_ms: 60 * 1000},
end

end
