defmodule ReefTest do
  @moduledoc false

  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog

  setup do
    :ok
  end

  @moduletag :reef
  setup_all do
    for dc <- prod_dutycycles(), do: Dutycycle.add(dc)
    :ok
  end

  test "Reef CLI" do
    rc = Reef.status(clear_screen: false)

    assert :ok == rc
  end

  test "keep_fresh()" do
    Reef.keep_fresh()

    assert true
  end

  test "mix_air()" do
    Reef.mix_air("fast")
    assert true
  end

  defp profile(:keep_fresh),
    do: %Dutycycle.Profile{name: "keep fresh", run_ms: 60_000, idle_ms: 60_000}

  defp prod_dutycycles,
    do: [
      %Dutycycle{
        name: "mix pump",
        comment: "mix pump",
        device: "mix_pump",
        active: false,
        log: true,
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
          %Dutycycle.Profile{
            name: "infinity",
            run_ms: 360_000,
            idle_ms: 360_000
          },
          profile(:keep_fresh)
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "mix air",
        comment: "mix air",
        device: "mix_air",
        active: false,
        log: true,
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
          %Dutycycle.Profile{
            name: "infinity",
            run_ms: 360_000,
            idle_ms: 360_000
          },
          profile(:keep_fresh)
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "mix rodi",
        comment: "mix rodi",
        device: "mix_rodi",
        active: false,
        log: true,
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
          %Dutycycle.Profile{
            name: "infinity",
            run_ms: 360_000,
            idle_ms: 360_000
          },
          profile(:keep_fresh)
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "mix rodi boost",
        comment: "mix rodi boost",
        device: "mix_rodi_boost",
        active: false,
        log: true,
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
          %Dutycycle.Profile{
            name: "infinity",
            run_ms: 360_000,
            idle_ms: 360_000
          },
          profile(:keep_fresh)
        ],
        state: %Dutycycle.State{}
      },
      %Dutycycle{
        name: "display tank ato",
        comment: "display tank ato",
        device: "display tank ato",
        active: false,
        log: true,
        profiles: [
          %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
          %Dutycycle.Profile{
            name: "infinity",
            run_ms: 360_000,
            idle_ms: 360_000
          },
          profile(:keep_fresh)
        ],
        state: %Dutycycle.State{}
      }
    ]
end
