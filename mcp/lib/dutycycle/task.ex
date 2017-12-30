defmodule Dutycycle.CycleTask do
@moduledoc """
"""

  require Logger
  use Timex
  use Task

  alias Dutycycle.State

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(dc) do
    profile = dc.profiles |> hd()
    Logger.info fn -> "cycle started for [#{dc.name}] " <>
                      "with profile [#{profile.name}]" end

    State.set_started(dc)

    loop(dc)

    # {:finished, dc.name}
  end

  defp loop(%Dutycycle{} = dc) do
    profile = dc.profiles |> hd()

    Logger.info fn -> "cycle running for #{profile.run_ms}ms" end
    State.set_running(dc)
    SwitchState.state(dc.device, true, :lazy)
    :timer.sleep(profile.run_ms)

    Logger.info fn -> "cycle idling for #{profile.idle_ms}ms" end
    State.set_idling(dc)
    SwitchState.state(dc.device, false, :lazy)
    :timer.sleep(profile.idle_ms)

    loop(dc)
  end

end
