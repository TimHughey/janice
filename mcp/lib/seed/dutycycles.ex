defmodule Seed.Dutycycles do
  @moduledoc """
  """
def dutycycles(env) when env in [:dev, :test] do
  [%Dutycycle{name: "duty 1",
    description: "duty 1 non-prod",
    device: "duty_1",
    modes: [%Dutycycle.Mode{name: "fast",
            active: true,
            run_ms: 1000, idle_ms: 1000},
           %Dutycycle.Mode{name: "slow",
            run_ms: 10_000, idle_ms: 10_000}],
    state: %Dutycycle.State{}},
   %Dutycycle{name: "duty 2",
     description: "duty 2 non-prod",
     device: "duty_2",
     modes: [%Dutycycle.Mode{name: "fast",
             run_ms: 2000, idle_ms: 2000},
            %Dutycycle.Mode{name: "slow",
             run_ms: 20_000, idle_ms: 20_000}],
     state: %Dutycycle.State{}},
   %Dutycycle{name: "duty 2",
     description: "duty 2 non-prod",
     device: "duty_2",
     modes: [%Dutycycle.Mode{name: "fast",
             run_ms: 2000, idle_ms: 2000},
            %Dutycycle.Mode{name: "slow",
             run_ms: 20_000, idle_ms: 20_000}],
     state: %Dutycycle.State{}}]
end

def dutycycles(:prod) do
  []
  # [%Dutycycle{name: "sump vent",
  #    description: "sump vent",
  #    enable: false, device_sw: "sump_vent",
  #    run_ms: 20 * 60 * 1000, idle_ms: 2 * 60 * 1000},
  #  %Dutycycle{name: "basement circulation",
  #    description: "basement circulation fan",
  #    enable: false, device_sw: "basement_fan",
  #    run_ms: 15 * 60 * 1000, idle_ms: 60 * 1000},
  #  %Dutycycle{name: "reefmix rodi slow",
  #    description: "periodic fill reefmix with rodi water",
  #    enable: true, device_sw: "reefmix_rodi_valve",
  #    run_ms: 900_000, idle_ms: 300_000},
  #  %Dutycycle{name: "reefmix rodi fast",
  #    description: "fill mixtank quickly",
  #    enable: false, device_sw: "reefmix_rodi_valve",
  #    run_ms: 3_600_000, idle_ms: 120_000}]
end


end
