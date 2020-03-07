defmodule Janitor do
  @moduledoc false

  require Logger
  use GenServer
  use Timex

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]
  import Janice.TimeSupport, only: [ms: 1, duration_from_list: 1]

  alias Fact.RunMetric

  @vsn :janitor0004

  @orphan_timer :orphan_timer
  @purge_timer :purge_timer

  defmacro __using__([]) do
    quote do
      Logger.info([
        "Janitor using: ",
        inspect(__MODULE__, pretty: true)
      ])
    end
  end

  def start_link(s) do
    defs = [
      log: [init: true],
      switch_cmds: [
        purge: true,
        interval: {:mins, 5},
        older_than: {:days, 7},
        log: false
      ],
      orphan_acks: [interval: {:mins, 1}, older_than: {:mins, 5}, log: true]
    ]

    opts = get_env(:mcp, Janitor, defs) |> Enum.into(%{})
    opts = Map.put(opts, :switch_cmds, Enum.into(opts.switch_cmds, %{}))
    opts = Map.put(opts, :orphan_acks, Enum.into(opts.orphan_acks, %{}))

    s = Map.put_new(s, :autostart, false)
    s = Map.put(s, :opts, opts)
    s = Map.put(s, @purge_timer, nil)
    s = Map.put(s, @orphan_timer, nil)
    s = Map.put(s, :track, %{})

    GenServer.start_link(Janitor, s, name: Janitor)
  end

  def terminate(reason, _state) do
    Logger.info(["terminating with reason ", inspect(reason, pretty: true)])
  end

  ## Callbacks

  # when autostart is true leverage handle_continue() to complete
  # startup activities
  def init(%{autostart: autostart, opts: %{log: log_opts}} = s) do
    log = Keyword.get(log_opts, :init, true)

    log && Logger.info(["init(): ", inspect(s, pretty: true)])

    if autostart == true,
      do: {:ok, s, {:continue, {:startup}}},
      else: {:ok, s}
  end

  @log_purge_cmd_msg :log_cmd_purge_msg
  def log_purge_cmds(val)
      when is_boolean(val) do
    GenServer.call(Janitor, {@log_purge_cmd_msg, val})
  end

  @manual_purge_msg :manual_cmds
  def manual_purge do
    GenServer.call(Janitor, {@manual_purge_msg})
  end

  @opts_msg :opts
  def opts(new_opts \\ %{}) when is_map(new_opts) do
    GenServer.call(Janitor, {@opts_msg, new_opts})
  end

  #
  # NOTE:
  #   track() and untrack() return the cmd untouched and return the
  #   cmd unchanged
  #

  # NOTE:  callers of this function will receive the cmd, unchanged,
  #        as the return value
  def track(%{refid: _refid} = cmd, opts) when is_list(opts) do
    GenServer.cast(__MODULE__, {:track, cmd, opts})
    cmd
  end

  # NOTE:  callers of this function will receive whatever was passed
  #        as parameters as the return value
  def untrack({:ok, %{refid: _refid} = cmd} = rc) do
    GenServer.cast(__MODULE__, {:untrack, cmd})
    rc
  end

  def untrack(anything), do: anything

  #
  ## GenServer callbacks
  #

  def handle_call({@opts_msg, %{} = new_opts}, _from, s) do
    opts = %{opts: new_opts}

    if Enum.empty?(new_opts) do
      {:reply, s.opts, s}
    else
      s = Map.merge(s, opts) |> schedule_purge() |> schedule_orphan()

      {:reply, s.opts, s}
    end
  end

  def handle_call({@log_purge_cmd_msg, val}, _from, s) do
    Logger.info(["switch cmds purge set to ", inspect(val)])
    new_opts = %{opts: %{switch_cmds: %{purge: val}}}
    s = Map.merge(s, new_opts)

    {:reply, :ok, s}
  end

  def handle_call({@manual_purge_msg}, _from, s) do
    Logger.info(["manual purge requested"])
    result = purge_sw_cmds(s)
    Logger.info(["manually purged ", inspect(result), " switch cmds"])

    {:reply, result, s}
  end

  def handle_cast(
        {:track, %{refid: refid} = cmd, opts},
        %{track: track} = s
      ) do
    track = Map.put(track, refid, %{cmd: cmd, opts: opts})

    # Janitor expects  a Keyword list of options with the key :orphan
    orphan_opts = Keyword.get(opts, :orphan, [])

    # this function expects to find sent_before: [key: val] in opts
    # get the key and convert it to milliseconds via TimeSupport
    orphan_timeout_ms =
      Keyword.get(orphan_opts, :sent_before, [])
      |> duration_from_list()
      |> Duration.to_milliseconds(truncate: true)

    if orphan_timeout_ms > 0,
      do:
        Process.send_after(self(), {:possible_orphan, refid}, orphan_timeout_ms),
      else:
        Logger.warn([
          "handle_cast(:track) could not determine orphan timeout from opts: ",
          inspect(opts, pretty: true)
        ])

    {:noreply, Map.put(s, :track, track)}
  end

  def handle_cast(
        {:untrack, %{refid: refid} = _cmd},
        %{track: track} = s
      ) do
    track = Map.delete(track, refid)

    {:noreply, Map.put(s, :track, track)}
  end

  def handle_continue({:startup}, %{opts: _opts} = s) do
    Process.flag(:trap_exit, true)

    s = schedule_orphan(s, 0)
    s = schedule_purge(s, 0)

    {:noreply, s}
  end

  def handle_continue(catchall, s) do
    Logger.warn(["handle_continue(catchall): ", inspect(catchall, pretty: true)])

    {:noreply, s}
  end

  def handle_info({:clean_orphan_acks}, s) when is_map(s) do
    clean_orphan_acks(s)

    s = schedule_orphan(s)

    {:noreply, s}
  end

  # NOTE:
  #   Janitor will receive an info message for EVERY tracked cmd after the
  #   configured orphan timeout has expired.  if the refid is not found in
  #   the track map then untrack was invoked and this is not an orphan
  #
  #   if refid was found in the track map then this cmd is POSSIBLY an
  #   orphan so invoke the possible_orphan() function for a final decision
  def handle_info({:possible_orphan, refid}, %{track: track} = s) do
    possible_orphan(Map.get(track, refid, :not_found), refid)

    # NOTE: Map.delete/2 silently returns an unchanged map if the requested
    #       key does not exist
    track = Map.delete(track, refid)

    {:noreply, Map.put(s, :track, track)}
  end

  def handle_info({:purge_switch_cmds}, s)
      when is_map(s) do
    purge_sw_cmds(s)

    s = schedule_purge(s)

    {:noreply, s}
  end

  def handle_info({:EXIT, _pid, reason} = msg, state) do
    Logger.info([
      ":EXIT msg: ",
      inspect(msg, pretty: true),
      " reason: ",
      inspect(reason, pretty: true)
    ])

    {:noreply, state}
  end

  def handle_info(catchall, s) do
    Logger.warn(["handle_info(catchall): ", inspect(catchall, pretty: true)])
    {:noreply, s}
  end

  #
  ## Private functions
  #

  defp clean_orphan_acks(s) when is_map(s) do
    opts = s.opts.orphan_acks
    {orphans, nil} = SwitchCmd.ack_orphans(opts)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "orphans_acked",
      val: orphans
    )

    if opts.log do
      orphans > 0 && Logger.info(["orphans ack'ed: [", inspect(orphans), "]"])
    end

    orphans
  end

  defp log_purge(s) do
    s.opts.switch_cmds.log
  end

  # Janitor will never make a final decision if a cmd is an orphan.  rather,
  # the owning module makes the decision.
  defp possible_orphan(%{cmd: %{refid: refid} = cmd, opts: opts}, _refid) do
    log = get_in(opts, [:orphan, :log])

    possible_orphaned_fn =
      Keyword.get(opts, :possible_orphaned_fn, fn x -> x end)

    orphan_rc = possible_orphaned_fn.(cmd)

    case orphan_rc do
      {:orphan, {:ok, %{refid: refid}}} ->
        log && Logger.warn(["orphaned refid ", inspect(refid, pretty: true)])

      # TODO: add RunMetric

      # return the actual results of module's orphan decision

      {:orphan, cmd_rc} ->
        Logger.warn([
          "orphaned refid ",
          inspect(refid, pretty: true),
          " with a problem:  ",
          inspect(cmd_rc, pretty: true)
        ])

      {:acked, _cmd_rc} ->
        log &&
          Logger.info(["refid ", inspect(refid, pretty: true), " already acked"])

      anything ->
        Logger.warn([
          "possible_orphan() unhandled rc: ",
          inspect(anything, pretty: true)
        ])
    end

    orphan_rc
  end

  defp possible_orphan(:not_found, refid) do
    Logger.debug([
      "refid ",
      inspect(refid, pretty: true),
      " not tracked, likely acked"
    ])

    {:ok, :not_found}
  end

  defp purge_sw_cmds(s)
       when is_map(s) do
    purged = SwitchCmd.purge_acked_cmds(s.opts.switch_cmds)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "sw_cmds_purged",
      val: purged
    )

    if log_purge(s) do
      purged > 0 &&
        Logger.info(["purged ", inspect(purged), " acked switch commands"])
    end

    purged
  end

  defp schedule_orphan(s),
    do: schedule_orphan(s, ms(s.opts.orphan_acks.interval))

  defp schedule_orphan(s, millis) do
    with false <- is_nil(Map.get(s, @orphan_timer, nil)),
         x when is_number(x) <- Process.read_timer(s.orphan_timer) do
      Process.cancel_timer(s.orphan_timer)
    end

    t = send_after(self(), {:clean_orphan_acks}, millis)
    Map.put(s, @orphan_timer, t)
  end

  defp schedule_purge(s),
    do: schedule_purge(s, ms(s.opts.switch_cmds.interval))

  defp schedule_purge(s, millis) do
    with false <- is_nil(Map.get(s, @purge_timer, nil)),
         x when is_number(x) <- Process.read_timer(s.purge_timer) do
      Process.cancel_timer(s.purge_timer)
    end

    t = send_after(self(), {:purge_switch_cmds}, millis)
    Map.put(s, @purge_timer, t)
  end
end
