defmodule Dutycycle.CycleTask do
@moduledoc """
"""

  alias __MODULE__

  require Logger
  use Timex
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(dc) do
    profile = dc.profiles |> hd()
    Logger.info fn -> "cycle started for [#{dc.name}] " <>
                      "with profile [#{profile.name}]" end

    loop(dc)

    # {:finished, dc.name}
  end

  defp loop(%Dutycycle{} = dc) do
    profile = dc.profiles |> hd()

    Logger.info fn -> "cycle running for #{profile.run_ms}ms" end
    SwitchState.state(dc.device, true)
    :timer.sleep(profile.run_ms)

    Logger.info fn -> "cycle idling for #{profile.idle_ms}ms" end
    SwitchState.state(dc.device, false)
    :timer.sleep(profile.idle_ms)

    loop(dc)
  end

end
