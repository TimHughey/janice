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
      one: 1,
      query: 1,
      preload: 2,
      update: 1,
      update_all: 2
    ]

  import Janice.TimeSupport, only: [utc_now: 0, ms: 1]
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
          metric: "rt_latency",
          device: cmd.name,
          val: opts.rt_latency
        )

        change(cmd, opts) |> update
    end
  end

  # if the above function doesn't match then this is not a cmd ack
  def ack_if_needed(%{}), do: :bad_cmd_ack

  def ack_orphans(opts) do
    # don't ack cmds before providing enough time for the round trip
    before = utc_now() |> Timex.shift(milliseconds: ms(opts.older_than) * -1)

    # set the lower limit on the check
    lower = utc_now() |> Timex.shift(milliseconds: ms(opts.interval) * -1)

    ack_at = utc_now()

    from(
      sc in SwitchCmd,
      update: [set: [acked: true, ack_at: ^ack_at, orphan: true]],
      where: sc.acked == false,
      where: sc.sent_at > ^lower,
      where: sc.sent_at < ^before
    )
    |> update_all([])
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

  def purge_acked_cmds(opts)
      when is_map(opts) do
    ms_ago = ms(opts.older_than)

    sql = ~s/delete from switch_cmd
              where acked = true and ack_at <
              now() at time zone 'utc' - interval '#{ms_ago} milliseconds'/

    query(sql) |> check_purge_acked_cmds()
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
      metric: "record_cmd_us",
      device: name,
      val: elapsed_us
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

  defp check_purge_acked_cmds({:error, e}) do
    Logger.warn(fn ->
      ~s/failed to purge acked cmds msg='#{inspect(e)}'/
    end)

    0
  end

  defp check_purge_acked_cmds({:ok, %{command: :delete, num_rows: nr}}), do: nr
end
