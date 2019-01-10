defmodule Dutycycle.State do
  @moduledoc """
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Query, only: [from: 2, update: 2]

  alias Dutycycle.Profile

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

  def as_map(%Dutycycle.State{} = dcs) do
    keys = [
      :id,
      :state,
      :dev_state,
      :run_at,
      :run_end_at,
      :idle_at,
      :idle_end_at,
      :started_at,
      :state_at
    ]

    Map.take(dcs, keys)
  end

  def set(opts) when is_list(opts) do
    rc = set(:raw_result, opts)

    if is_tuple(rc) and elem(rc, 0) > 0, do: :ok, else: rc
  end

  def set(:raw_result, opts) when is_list(opts) do
    mode = Keyword.get(opts, :mode, nil)
    dc = Keyword.get(opts, :dutycycle, %{})
    dc_id = Map.get(dc, :id, false)
    profile = Map.get(dc, :profiles) |> Profile.active()

    now = DateTime.utc_now()
    query = from(s in Dutycycle.State, where: s.dutycycle_id == ^dc_id)

    cond do
      is_nil(mode) or dc_id == false ->
        :bad_args

      profile === :none ->
        :no_active_profile

      mode === "idle" ->
        Switch.state(dc.device, position: false, lazy: true, log: false)

        idle_end_at =
          Timex.to_datetime(now, "UTC")
          |> Timex.shift(milliseconds: profile.idle_ms)

        query
        |> update(
          set: [
            state: "idling",
            dev_state: false,
            idle_at: ^now,
            idle_end_at: ^idle_end_at,
            run_at: nil,
            run_end_at: nil,
            state_at: ^now
          ]
        )
        |> Repo.update_all([])

      mode === "run" ->
        Switch.state(dc.device, position: true, lazy: true, log: false)

        run_end_at =
          Timex.to_datetime(now, "UTC")
          |> Timex.shift(milliseconds: profile.run_ms)

        query
        |> update(
          set: [
            state: "running",
            dev_state: true,
            idle_at: nil,
            idle_end_at: nil,
            run_at: ^now,
            run_end_at: ^run_end_at,
            state_at: ^now
          ]
        )
        |> Repo.update_all([])

      mode === "stop" ->
        Switch.state(dc.device, position: false, lazy: true, ack: false, log: false)

        query
        |> update(
          set: [
            state: "stopped",
            dev_state: false,
            idle_at: nil,
            idle_end_at: nil,
            run_at: nil,
            run_end_at: nil,
            started_at: nil,
            state_at: ^now
          ]
        )
        |> Repo.update_all([])

      true ->
        :bad_args
    end
  end
end
