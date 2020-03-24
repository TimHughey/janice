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
      preload: 2,
      update: 1
    ]

  import Janice.TimeSupport,
    only: [
      duration: 1,
      utc_now: 0,
      utc_shift: 1
    ]

  import Mqtt.Client, only: [publish_cmd: 1]

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
        Logger.debug([
          "refid ",
          inspect(refid, pretty: true),
          " not found, won't ack"
        ])

        {:not_found, refid}

      cmd ->
        rt_latency_us = Timex.diff(recv_dt, cmd.sent_at, :microseconds)
        rt_latency_ms = rt_latency_us / 1000.0

        log &&
          Logger.debug([
            inspect(cmd.name, pretty: true),
            " acking refid ",
            inspect(refid),
            " rt_latency=",
            inspect(rt_latency_ms),
            "ms"
          ])

        # log a warning for more than 150ms rt_latency, helps with tracking down prod issues
        rt_latency_ms > latency_warn_ms &&
          Logger.warn([
            inspect(cmd.name, pretty: true),
            " rt_latency=",
            inspect(rt_latency_ms),
            "ms exceeded ",
            inspect(latency_warn_ms),
            "ms"
          ])

        opts = %{
          acked: true,
          rt_latency: rt_latency_us,
          ack_at: utc_now()
        }

        RunMetric.record(
          module: "#{__MODULE__}",
          metric: "sw_cmd_rt_latency_us",
          device: cmd.name,
          val: rt_latency_us,
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
    oldest =
      Map.get(opts, :older_than)
      |> duration()
      |> Duration.invert()
      |> utc_shift()

    #   oldest = utc_now() |> Timex.shift(milliseconds: ms(opts.older_than) * -1)

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

                  [
                    inspect(u.name, pretty: true),
                    " ack'ed orphan sent ",
                    sent_ago,
                    " ago"
                  ]
                end)

            {:error, changeset} ->
              log &&
                Logger.error([
                  "failed to ack orphan: ",
                  inspect(changeset, pretty: true)
                ])
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

  def purge_acked_cmds(%{older_than: older_than}) do
    before =
      older_than
      |> duration()
      |> Duration.invert()
      |> utc_shift()

    q =
      from(
        cmd in SwitchCmd,
        where: cmd.acked == true,
        where: cmd.ack_at < ^before
      )

    Repo.delete_all(q) |> check_purge_acked_cmds()
  end

  # older_than configuration value is missing
  def purge_acked_cmds(_opts) do
    {:unconfigured, "commands not purged because :older_than is unavailable"}
    |> check_purge_acked_cmds()
  end

  def record_cmd(%SwitchState{} = ss, opts) when is_list(opts) do
    if Keyword.get(opts, :record_cmd, false),
      do: record_cmd(:record_cmd, ss, opts),
      else: [switch_state: ss] ++ opts
  end

  def record_cmd(:record_cmd, %SwitchState{name: name} = ss, opts)
      when is_list(opts) do
    log = Keyword.get(opts, :log, false)
    publish = Keyword.get(opts, :publish, true)
    cmd_map = Keyword.get(opts, :cmd_map)

    # ensure the associated switch is loaded
    ss = preload(ss, :switch)
    %SwitchState{switch: %Switch{device: device} = switch} = ss

    {elapsed_us, refid} =
      :timer.tc(fn ->
        # create and presist a new switch comamnd (also updates last switch cmd)
        refid = Switch.add_cmd(name, switch, utc_now())

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
        if publish do
          log &&
            Logger.debug([
              "publishing switch cmd for ",
              inspect(name, pretty: true),
              " ",
              inspect(device, pretty: true)
            ])

          SetSwitch.new_cmd(device, [cmd_map], refid, opts)
          |> publish_cmd()
        end

        refid
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "sw_cmd_db_persist_us",
      device: name,
      val: elapsed_us,
      record: true
    )

    [switch_state: ss, refid: refid] ++ opts
  end

  #
  # Private functions
  #

  defp check_purge_acked_cmds({:ok, %{command: :delete, num_rows: nr}}), do: nr

  defp check_purge_acked_cmds({flag, e} = x) when is_atom(flag) do
    case flag do
      :unconfigured ->
        Logger.debug([
          "check_purge_acked_cmds() flag: :unconfigured error: ",
          inspect(e, pretty: true)
        ])

      :error ->
        Logger.warn([
          "command purge failed: ",
          inspect(e, pretty: true)
        ])

      _default ->
        Logger.warn([
          "unhandled command purge result: ",
          inspect(x, pretty: true)
        ])
    end

    # return zero messages purged
    0
  end

  defp check_purge_acked_cmds({records, nil}) when is_number(records),
    do: records
end
