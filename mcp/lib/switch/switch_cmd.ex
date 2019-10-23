defmodule SwitchCmd do
  @moduledoc """
    The SwithCommand module provides the database schema for tracking
    commands sent for a Switch.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  import Repo,
    only: [
      all: 1,
      all: 2,
      delete_all: 2,
      one: 1,
      preload: 2,
      update: 1
    ]

  import Janice.TimeSupport, only: [before_time: 2, ms: 1, utc_now: 0]
  import Mqtt.Client, only: [publish_switch_cmd: 1]

  alias Fact.RunMetric
  alias Mqtt.SetSwitch

  schema "switch_cmd" do
    field(:refid, :string)
    field(:name, :string)
    field(:acked, :boolean)
    field(:orphan, :boolean)
    field(:rt_latency, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)
    belongs_to(:switch, Switch)

    timestamps(usec: true)
  end

  def ack_now(refid, opts \\ []) when is_binary(refid) do
    %{cmdack: true, refid: refid, msg_recv_dt: utc_now()}
    |> Map.merge(Enum.into(opts, %{}))
    |> ack_if_needed()
  end

  def ack_if_needed(%{cmdack: true, refid: refid, msg_recv_dt: recv_dt} = m)
      when is_binary(refid) do
    log = Map.get(m, :log, true)
    latency_warn_ms = Map.get(m, :latency_warn_ms, 1000)

    cmd =
      from(
        cmd in SwitchCmd,
        where: cmd.refid == ^refid
        # preload: [:switch]
      )
      |> one()

    case cmd do
      nil ->
        Logger.warn(fn ->
          "cmd for refid [#{refid}] not found, won't ack"
        end)

        {:not_found, refid}

      cmd ->
        rt_latency = Timex.diff(recv_dt, cmd.sent_at, :microseconds)
        rt_latency_ms = rt_latency / 1000.0

        log &&
          Logger.debug(fn ->
            "#{inspect(cmd.name)} acking refid #{inspect(refid)} rt_latency=#{
              rt_latency_ms
            }ms"
          end)

        # log a warning for more than 150ms rt_latency, helps with tracking down prod issues
        rt_latency_ms > latency_warn_ms &&
          Logger.warn(fn ->
            "#{inspect(cmd.name)} rt_latency=#{rt_latency_ms}ms exceeded #{
              latency_warn_ms
            }ms"
          end)

        opts = %{
          acked: true,
          rt_latency: rt_latency,
          ack_at: utc_now()
        }

        RunMetric.record(
          module: "#{__MODULE__}",
          metric: "switch_cmd_rt_latency_ms",
          device: cmd.name,
          val: opts.rt_latency,
          record: Map.get(m, :log_roundtrip_times, false)
        )

        change(cmd, opts) |> update
    end
  end

  # if the above function doesn't match then this is not a cmd ack
  def ack_if_needed(%{}), do: :bad_cmd_ack

  def ack_orphans(opts) do
    log = opts.log
    # set a lower limit to improve performance
    lower_limit = utc_now() |> Timex.shift(days: -1)

    # compute the date / time of what is considered an orphan
    oldest = utc_now() |> Timex.shift(milliseconds: ms(opts.older_than) * -1)

    ack_at = utc_now()

    query =
      from(
        sc in SwitchCmd,
        where: sc.acked == false,
        where: sc.sent_at > ^lower_limit,
        where: sc.sent_at < ^oldest
      )

    orphans = all(query)

    if Enum.empty?(orphans) do
      {0, nil}
    else
      o =
        for s <- orphans do
          cs = change(s, acked: true, ack_at: ack_at, orphan: true)

          case update(cs) do
            {:ok, u} ->
              log &&
                Logger.warn(fn ->
                  sent_ago =
                    Timex.diff(Timex.now(), u.sent_at, :duration)
                    |> Timex.format_duration(:humanized)

                  # lower = Timex.from_now(lower_limit)
                  # oldest = Timex.from_now(oldest)

                  "#{u.name} ack'ed orphan sent #{sent_ago} ago"
                end)

            {:error, changeset} ->
              log &&
                Logger.error(fn ->
                  "failed to ack orphan: #{inspect(changeset, pretty: true)}"
                end)
          end
        end

      {Enum.count(o), nil}
    end
  end

  def get_rt_latency(list, name) when is_list(list) and is_binary(name) do
    Enum.find(list, %SwitchCmd{rt_latency: 0}, fn x -> x.name === name end)
    |> Map.from_struct()
  end

  def is_acked?(refid) when is_binary(refid) do
    cmd = from(sc in SwitchCmd, where: sc.refid == ^refid) |> one()

    if is_nil(cmd), do: false, else: cmd.acked
  end

  def last_cmds(max_rows) when is_integer(max_rows) do
    from(
      sc in SwitchCmd,
      where: not is_nil(sc.ack_at),
      order_by: [desc: sc.ack_at],
      limit: ^max_rows
    )
    |> all()
  end

  def unacked do
    from(
      cmd in SwitchCmd,
      join: sw in assoc(cmd, :switch),
      join: states in assoc(sw, :states),
      where: cmd.name == states.name,
      where: cmd.acked == false,
      preload: [switch: :states]
    )
    |> all(timeout: 100)
  end

  def unacked_count, do: unacked_count([])

  def unacked_count(opts)
      when is_list(opts) do
    minutes_ago = Keyword.get(opts, :minutes_ago, 0)

    earlier = utc_now() |> Timex.shift(minutes: minutes_ago * -1)

    from(
      c in SwitchCmd,
      where: c.acked == false,
      where: c.sent_at < ^earlier,
      select: count(c.id)
    )
    |> one()
  end

  def pending_cmds(%Switch{} = sw, opts \\ []) do
    timescale = Keyword.get(opts, :minutes, -15) * 60 * 1000
    timescale = Keyword.get(opts, :seconds, timescale)
    timescale = Keyword.get(opts, :milliseconds, timescale)

    # a reasonable default for the timescale of pending cmds appears to be 15mins
    since = utc_now() |> Timex.shift(milliseconds: timescale)

    from(
      cmd in SwitchCmd,
      where: cmd.switch_id == ^sw.id,
      where: cmd.acked == false,
      where: cmd.sent_at >= ^since,
      select: count(cmd.id)
    )
    |> one()
  end

  def purge_acked_cmds(%{older_than: older_than} = opts) do
    # use purge_timeout configuration if available
    # otherwise, default to reasonable default
    timeout = Map.get(opts, :purge_timeout, {:ms, 100}) |> ms()

    before = before_time(:utc_now, older_than)

    q =
      from(
        cmd in SwitchCmd,
        where: cmd.acked == true,
        where: cmd.ack_at < ^before
      )

    delete_all(q, timeout: timeout) |> check_purge_acked_cmds()
  end

  # older_than configuration value is missing
  def purge_acked_cmds(_opts) do
    {:unconfigured, "commands not purged because :older_than is unavailable"}
    |> check_purge_acked_cmds()
  end

  # header for function with optional args
  def record_cmd(name, ss, opts \\ [])

  def record_cmd(name, %SwitchState{} = ss, opts) when is_binary(name) do
    log = Keyword.get(opts, :log, true)

    # ensure the associated switch is loaded
    ss = preload(ss, :switch)

    {elapsed_us, refid} =
      :timer.tc(fn ->
        # create and presist a new switch comamnd (also updates last switch cmd)
        refid = Switch.add_cmd(name, ss.switch, utc_now())

        # NOTE: if :ack is missing from opts then default to true
        if Keyword.get(opts, :ack, true) do
          # nothing, will be acked by remote device
        else
          # ack is false so create a simulated ack and immediately process it
          %{
            cmdack: true,
            refid: refid,
            msg_recv_dt: utc_now(),
            log: log
          }
          |> ack_if_needed()
        end

        # create and publish the actual command to the remote device
        # if the publish option is true or does not exist
        if Keyword.get(opts, :publish, true) do
          state_map = SwitchState.as_map(ss)

          remote_cmd =
            SetSwitch.new_cmd(ss.switch.device, [state_map], refid, opts)

          publish_switch_cmd(SetSwitch.json(remote_cmd))
        end

        refid
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "switch_cmd_db_persist_us",
      device: name,
      val: elapsed_us,
      record: true
    )

    {:ok, refid}
  end

  def record_cmd(name, %SwitchState{} = ss, opts) do
    Logger.warn(fn -> "SwitchCmd.record_cmd() invoked with bad args:" end)
    Logger.warn(fn -> "  name: #{inspect(name)}" end)
    Logger.warn(fn -> "  ss: #{inspect(ss)}" end)
    Logger.warn(fn -> "  opts: #{inspect(opts)}" end)
    {:fail, nil}
  end

  #
  # Private functions
  #

  defp check_purge_acked_cmds({:ok, %{command: :delete, num_rows: nr}}), do: nr

  defp check_purge_acked_cmds({flag, e} = x) when is_atom(flag) do
    case flag do
      :unconfigured ->
        Logger.debug(fn -> e end)

      :error ->
        Logger.warn(fn ->
          ~s/command purge failed: #{inspect(e, pretty: true)} /
        end)

      _default ->
        Logger.warn(fn ->
          ~s/unhandled command purge result: #{inspect(x, pretty: true)}/
        end)
    end

    # return zero messages purged
    0
  end

  defp check_purge_acked_cmds({records, nil}) when is_number(records),
    do: records
end
