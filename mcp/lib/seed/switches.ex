defmodule Seed.Switches do
  @moduledoc false

  def switches(env) when env in [:dev, :test] do
    [
      %Switch{
        device: "ds/2pos1",
        states: [%SwitchState{name: "sw1", pio: 0}, %SwitchState{name: "sw2", pio: 1}]
      },
      %Switch{
        device: "ds/2pos2",
        states: [%SwitchState{name: "sw3", pio: 0}, %SwitchState{name: "sw4", pio: 1}]
      },
      %Switch{
        device: "ds/2pos3",
        states: [%SwitchState{name: "sw5", pio: 0}, %SwitchState{name: "sw6", pio: 1}]
      },
      %Switch{
        device: "ds/2pos4",
        states: [%SwitchState{name: "sw7", pio: 0}, %SwitchState{name: "sw8", pio: 1}]
      },
      %Switch{
        device: "ds/2pos5",
        states: [%SwitchState{name: "sw9", pio: 0}, %SwitchState{name: "sw10", pio: 1}]
      },
      %Switch{
        device: "ds/2pos6",
        states: [%SwitchState{name: "sw11", pio: 0}, %SwitchState{name: "sw12", pio: 1}]
      },
      %Switch{
        device: "ds/2pos7",
        states: [%SwitchState{name: "sw13", pio: 0}, %SwitchState{name: "sw14", pio: 1}]
      }
    ]
  end

  def switches(:prod) do
    [
      %Switch{
        device: "ds/12197521000000",
        states: [
          %SwitchState{name: "display_tank_replenish", pio: 0},
          %SwitchState{name: "mixtank_pump", pio: 1}
        ]
      },
      %Switch{
        device: "ds/12328621000000",
        states: [
          %SwitchState{name: "loop_indicator", pio: 0},
          %SwitchState{name: "mixtank_heater", pio: 1}
        ]
      },
      %Switch{
        device: "ds/12376621000000",
        states: [
          %SwitchState{name: "unused2", pio: 0},
          %SwitchState{name: "shroom1_heat", pio: 1}
        ]
      },
      %Switch{
        device: "ds/12606e21000000",
        states: [
          %SwitchState{name: "shroom2_heat", pio: 0},
          %SwitchState{name: "unused3", pio: 1}
        ]
      },
      %Switch{
        device: "ds/29463408000000",
        states: [
          %SwitchState{name: "shroom1_mist", pio: 0},
          %SwitchState{name: "mixtank_air", pio: 1},
          %SwitchState{name: "unused4", pio: 2},
          %SwitchState{name: "reefmix_rodi_valve", pio: 3},
          %SwitchState{name: "shroom1_fresh_air", pio: 4},
          %SwitchState{name: "shroom2_stir", pio: 5},
          %SwitchState{name: "shroom1_air", pio: 6},
          %SwitchState{name: "am2315_pwr", pio: 7}
        ]
      }
    ]
  end
end
