defmodule PulseWidthCmd do
  @moduledoc """
    The PulseWidthCmd module provides the database schema for tracking
    commands sent for a PulseWidth.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset

  use Janitor

  schema "pwm_cmd" do
    field(:refid, Ecto.UUID, autogenerate: true)
    field(:acked, :boolean)
    field(:orphan, :boolean)
    field(:rt_latency_us, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)
    belongs_to(:pwm, PulseWidth, foreign_key: :pwm_id)

    timestamps(usec: true)
  end

  def acked?(refid) do
    cmd = find_refid(refid)

    if is_nil(cmd), do: false, else: cmd.acked
  end

  # primary entry point when called from PulseWidth and an ack is needed
  # checks the return code from the update to the PulseWidth
  def ack_if_needed(
        {:ok, %PulseWidth{log: log}},
        %{cmdack: true, refid: refid} = m
      ) do
    log &&
      Logger.info(["attempting to ack refid: ", inspect(refid, pretty: true)])

    find_refid(refid) |> ack_if_needed(m)
  end

  # primary entry point when called from PulseWidth and an ack is not needed
  def ack_if_needed({:ok, %PulseWidth{}} = rc, %{}), do: rc

  # handles acking once the PulseWidthCmd has been retrieved
  def ack_if_needed(
        %PulseWidthCmd{sent_at: sent_at} = cmd,
        %{msg_recv_dt: recv_dt}
      ) do
    set = [
      rt_latency_us: Timex.diff(recv_dt, sent_at, :microsecond),
      acked: true,
      ack_at: utc_now()
    ]

    update(cmd, set)
    |> untrack()
  end

  # error / unmatched function call handling
  def ack_if_needed(nil, %{refid: refid}) do
    Logger.warn(["ack_if_needed() could not find refid: ", inspect(refid)])
    {:not_found, refid}
  end

  def ack_if_needed(catchall) do
    Logger.warn(["ack_if_needed() catchall: ", inspect(catchall, pretty: true)])
    {:error, catchall}
  end

  def ack_now(refid, opts \\ []) do
    %{cmdack: true, refid: refid, msg_recv_dt: utc_now()}
    |> Map.merge(Enum.into(opts, %{}))
    |> ack_if_needed()
  end

  def add(%PulseWidth{} = pwm, %DateTime{} = dt) do
    Ecto.build_assoc(
      pwm,
      :cmds,
      sent_at: dt
    )
    |> Repo.insert!(returning: true)
    |> track()
  end

  def find_refid(refid),
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
    pwmc = find_refid(refid)

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
      :rt_latency_us,
      :sent_at,
      :ack_at
    ]
end
