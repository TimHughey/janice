defmodule PulseWidthCmd do
  @moduledoc """
    The SwithCommand module provides the database schema for tracking
    commands sent for a Switch.
  """

  require Logger
  use Timex
  use Ecto.Schema

  # import Ecto.Query, only: [from: 2]

  import Ecto.Changeset

  #   only: [
  #     all: 1,
  #     all: 2,
  #     delete_all: 2,
  #     one: 1,
  #     preload: 2,
  #     update: 1
  #   ]
  #
  import Janice.TimeSupport, only: [utc_now: 0]

  # import Mqtt.Client, only: [publish_cmd: 1]
  #
  # alias Fact.RunMetric
  # alias Mqtt.SetSwitch

  schema "pwm_cmd" do
    field(:refid, :string)
    field(:acked, :boolean)
    field(:orphan, :boolean)
    field(:rt_latency_ms, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)
    belongs_to(:pwm, PulseWidth, foreign_key: :pwm_id)

    timestamps(usec: true)
  end

  def acked?(refid) when is_binary(refid) do
    cmd = find(refid)

    if is_nil(cmd), do: false, else: cmd.acked
  end

  def ack_now(refid, opts \\ []) when is_binary(refid) do
    %{cmdack: true, refid: refid, msg_recv_dt: utc_now()}
    |> Map.merge(Enum.into(opts, %{}))
    |> ack_if_needed()
  end

  def ack_if_needed(
        %PulseWidthCmd{sent_at: sent_at} = cmd,
        %{msg_recv_dt: recv_dt}
      ) do
    set = [
      Timex.diff(recv_dt, sent_at, :microseconds),
      acked: true,
      ack_at: utc_now()
    ]

    update(cmd, set)
  end

  def ack_if_needed(nil, %{refid: refid}) when is_binary(refid) do
    Logger.warn(["ack_if_needed() could not find refid: ", inspect(refid)])
    {:not_found, refid}
  end

  def ack_if_needed(%{cmdack: true, refid: refid} = m) when is_binary(refid),
    do: find(refid) |> ack_if_needed(m)

  def find(refid) when is_binary(refid),
    do: Repo.get_by(__MODULE__, refid: refid) |> Repo.preload([:pwm])

  def reload(%PulseWidthCmd{id: id}), do: reload(id)

  def reload(id) when is_integer(id),
    do: Repo.get_by(__MODULE__, id: id) |> Repo.preload([:pwm])

  defp changeset(pwmc, params) when is_list(params),
    do: changeset(pwmc, Enum.into(params, %{}))

  defp changeset(pwmc, params) when is_map(params) do
    pwmc
    |> cast(params, possible_changes())
    |> validate_required(possible_changes())
    |> unique_constraint(:refid, name: :pwm_cmd_refid_index)
  end

  def update(refid, opts) when is_binary(refid) and is_list(opts) do
    pwmc = find(refid)

    if is_nil(pwmc), do: {:not_found, refid}, else: Repo.update(pwmc, opts)
  end

  def update(%PulseWidthCmd{} = pwmc, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})
    cs = changeset(pwmc, set)

    if cs.valid?,
      do: {:ok, Repo.update!(cs) |> reload()},
      else: {:invalid_changes, cs}
  end

  defp possible_changes,
    do: [
      :refid,
      :acked,
      :orphan,
      :rt_latency_ms,
      :sent_at,
      :ack_at
    ]
end
