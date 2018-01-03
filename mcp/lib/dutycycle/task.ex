defmodule Dutycycle.CycleTask do
@moduledoc """
"""

  require Logger
  use Timex
  use Task

  alias Dutycycle.Profile
  alias Dutycycle.State

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(dc, opts) do
    p = dc.profiles |> hd()
    Logger.info fn -> "[#{dc.name}] started with profile [#{p.name}]" end

    State.set_started(dc)

    loop(dc, opts)
  end

  defp loop(%Dutycycle{} = dc, opts) do
    profile = dc.profiles |> hd()

    run_phase(dc, profile, opts)
    idle_phase(dc, profile, opts)

    loop(dc, opts)
  end

  defp idle_phase(%Dutycycle{} = dc,
                  %Profile{idle_ms: idle_ms, name: profile}, _opts)
  when idle_ms < 1 do
    Logger.debug fn -> "[#{dc.name}] profile [#{profile}] idle_ms < 1, " <>
                      "skipping idle phase" end
    State.set_idling(dc)
  end

  defp idle_phase(%Dutycycle{} = dc,
                  %Profile{idle_ms: idle_ms}, _opts)
  when idle_ms > 0 do
    dc.log && Logger.info fn -> "[#{dc.name}] idling for #{idle_ms}ms" end
    State.set_idling(dc)

    :timer.sleep(idle_ms)
  end

  defp run_phase(%Dutycycle{} = dc,
                 %Profile{run_ms: run_ms, name: profile}, _opts)
  when run_ms < 1 do
    Logger.debug fn -> "[#{dc.name}] profile [#{profile}] run_ms < 1, " <>
                      "skipping run phase" end
    State.set_running(dc)
  end

  defp run_phase(%Dutycycle{} = dc,
                 %Profile{run_ms: run_ms}, _opts)
  when run_ms > 0 do
    dc.log && Logger.info fn -> "[#{dc.name}] running for #{run_ms}ms" end
    State.set_running(dc)

    :timer.sleep(run_ms)
  end

end
