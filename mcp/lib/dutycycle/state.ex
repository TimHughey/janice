defmodule Dutycycle.State do
  @moduledoc false

  require Logger
  use Timex
  use Ecto.Schema

  import Repo, only: [update!: 1]
  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  alias Dutycycle.Profile
  alias Dutycycle.State
  alias Janice.TimeSupport

  schema "dutycycle_state" do
    field(:state)
    field(:dev_state, :boolean)
    field(:run_at, :utc_datetime_usec)
    field(:run_end_at, :utc_datetime_usec)
    field(:idle_at, :utc_datetime_usec)
    field(:idle_end_at, :utc_datetime_usec)
    field(:started_at, :utc_datetime_usec)
    field(:state_at, :utc_datetime_usec)
    belongs_to(:dutycycle, Dutycycle)

    timestamps(usec: true)
  end

  # REFACTORED
  def state(%Dutycycle{state: state}),
    do: Map.get(state, :state, %State{state: "stopped"})

  # REFACTORED
  def mode(%State{state: state}), do: state

  # REFACTORED
  def next_phase(:run, %Dutycycle{} = dc), do: run(dc)
  def next_phase(:idle, %Dutycycle{} = dc), do: idle(dc)
  def next_phase(:offline, %Dutycycle{} = dc), do: offline(dc)
  def next_phase(:stop, %Dutycycle{} = dc), do: stop(dc)

  # REFACTORED
  def idle(%Dutycycle{state: st} = dc) do
    {dc, update_states_only(st, state: "idling", dev_state: false)}
  end

  # REFACTORED
  def idling?(%Dutycycle{state: %State{state: "idling"}}), do: true
  def idling?(%Dutycycle{state: %State{state: _}}), do: false

  # REFACTORED
  def offline(%Dutycycle{} = dc) do
    {dc, stop(dc, "offline")}
  end

  # REFACTORED
  def offline?(%Dutycycle{state: %State{state: "offline"}}), do: true
  def offline?(%Dutycycle{state: %State{state: _}}), do: false

  # REFACTORED
  def run(%Dutycycle{name: name, state: st, log: log} = dc) do
    log &&
      Logger.debug(fn -> "dutycycle #{inspect(name)} setting state to run" end)

    {dc, update_states_only(st, state: "running", dev_state: true)}
  end

  # REFACTORED
  def running?(%Dutycycle{state: %State{state: "running"}}), do: true
  def running?(%Dutycycle{state: %State{state: _}}), do: false

  # REFACTORED
  def stop(%Dutycycle{state: st} = dc, state \\ "stopped")
      when is_binary(state) do
    {dc, update_states_only(st, state: state, dev_state: false)}
  end

  # REFACTORED
  def stopped?(%Dutycycle{state: %State{state: "stopped"}}), do: true
  def stopped?(%Dutycycle{state: %State{state: _}}), do: false

  # REFACTORED
  def persist_phase_timer(
        %State{state: state} = st,
        %Profile{idle_ms: idle_ms, run_ms: run_ms},
        timer
      ) do
    cond do
      state === "running" ->
        Logger.debug(fn -> "persist_phase_timer() handling state 'running')" end)

        update(
          st,
          calculate_at(timer, run_ms, at_key: :run_at, at_end_key: :run_end_at)
        )

      state === "idling" ->
        update(
          st,
          calculate_at(timer, idle_ms,
            at_key: :idle_at,
            at_end_key: :idle_end_at
          )
        )

      true ->
        Logger.warn(fn ->
          "persist_phase_timer(): unhandled state #{inspect(state)}, " <>
            "setting at times to nil"
        end)

        update(st, nil_phase_at_times())
    end
  end

  #####################
  # Private Functions #
  #####################

  defp add_state_at(opts), do: opts ++ [state_at: TimeSupport.utc_now()]

  defp calculate_at(timer, total_ms, opts)
       when is_reference(timer) and is_list(opts) do
    {:at_key, at_key} = Keyword.take(opts, [:at_key]) |> hd()
    {:at_end_key, at_end_key} = Keyword.take(opts, [:at_end_key]) |> hd()

    # state start at:
    #  current time minus total phase_ms minus the remaining timer
    #
    # state end at:
    #  current time plus the remaining timer

    remaining_ms = Process.read_timer(timer)

    []
    |> Keyword.put(at_key, shift_ms((total_ms - remaining_ms) * -1))
    |> Keyword.put(at_end_key, shift_ms(remaining_ms))
  end

  # REFACTORED
  defp changeset(st, params),
    do:
      st
      |> cast(params, possible_changes())
      |> validate_required(required_changes())

  # REFACTORED
  defp nil_phase_at_times,
    do: [idle_at: nil, idle_end_at: nil, run_at: nil, run_end_at: nil]

  # REFACTORED
  defp possible_changes,
    do: [
      :state,
      :dev_state,
      :run_at,
      :run_end_at,
      :idle_at,
      :idle_end_at,
      :started_at,
      :state_at
    ]

  # REFACTORED
  defp required_changes, do: [:state, :dev_state]

  defp shift_ms(ms),
    do:
      TimeSupport.utc_now()
      |> Timex.shift(milliseconds: ms)

  # REFACTORED
  defp update(%State{} = st, opts) when is_list(opts) do
    opts = add_state_at(opts)
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(st, set)

    if cs.valid? do
      Logger.debug(fn -> "state update\n#{inspect(cs, pretty: true)}" end)
      st = update!(cs)
      {:ok, st}
    else
      {:invalid_changes, cs}
    end
  end

  # REFACTORED
  defp update_states_only(%State{} = st, opts)
       when is_list(opts) do
    opts = add_state_at(opts)

    set =
      (Keyword.take(opts, [:state, :dev_state, :state_at]) ++
         nil_phase_at_times())
      |> Enum.into(%{})

    cs = changeset(st, set)

    if cs.valid? do
      Logger.debug(fn ->
        "state update_states_only cs #{inspect(cs, pretty: true)}"
      end)

      st = update!(cs)
      {:ok, st}
    else
      {:invalid_changes, cs}
    end
  end
end
