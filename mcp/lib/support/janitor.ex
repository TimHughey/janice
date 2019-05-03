defmodule Janitor do
  @moduledoc false

  require Logger
  use GenServer
  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]
  import Janice.TimeSupport, only: [ms: 1]

  alias Fact.RunMetric

  @vsn :janitor0003

  @orphan_timer :orphan_timer
  @purge_timer :purge_timer

  def start_link(s) do
    defs = [
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

    s = Map.put(s, :opts, opts)
    s = Map.put(s, @purge_timer, nil)
    s = Map.put(s, @orphan_timer, nil)

    GenServer.start_link(Janitor, s, name: Janitor)
  end

  def terminate(reason, _state) do
    Logger.info(fn -> "terminating with reason #{inspect(reason)}" end)
  end

  ## Callbacks

  def init(s)
      when is_map(s) do
    case Map.get(s, :autostart, false) do
      true -> send_after(self(), {:startup}, 0)
      false -> nil
    end

    Logger.info("init()")

    {:ok, s}
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
  def opts(new_opts \\ []) do
    GenServer.call(Janitor, {@opts_msg, new_opts})
  end

  #
  ## GenServer callbacks
  #

  def code_change(old_vsn, %{} = state, extra) when is_atom(old_vsn) do
    s = do_code_change(old_vsn, state, extra)
    {:ok, s}
  end

  def code_change(old_vsn, state, extra) do
    Logger.warn(fn ->
      "code_change() unrecognized params: " <>
        "#{inspect(old_vsn)} " <>
        "#{inspect(state)} " <>
        "#{inspect(extra)}"
    end)

    {:error, :bad_params}
  end

  # if an empty list this is a request for the current configred opts
  def handle_call({@opts_msg, []}, _from, s) do
    {:reply, s.opts, s}
  end

  # if there is a non-empty list then set the opts to the list
  def handle_call({@opts_msg, new_opts}, _from, s)
      when is_list(new_opts) do
    opts = %{opts: new_opts}
    s = Map.merge(s, opts)

    # reschedule purge won't do anything if the interval is the same
    s = reschedule_purge(s, new_opts)

    {:reply, s.opts, s}
  end

  def handle_call({@log_purge_cmd_msg, val}, _from, s) do
    Logger.info(fn -> "switch cmds purge set to #{inspect(val)}" end)
    new_opts = %{opts: %{switch_cmds: %{purge: val}}}
    s = Map.merge(s, new_opts)

    {:reply, :ok, s}
  end

  def handle_call({@manual_purge_msg}, _from, s) do
    Logger.info(fn -> "manual purge requested" end)
    result = purge_sw_cmds(s)
    Logger.info(fn -> "manually purged #{result} switch cmds" end)

    {:reply, result, s}
  end

  def handle_info({:startup}, s)
      when is_map(s) do
    opts = Map.get(s, :opts)

    Logger.debug(fn -> "startup(), opts: #{inspect(opts)}" end)

    Process.flag(:trap_exit, true)

    s = schedule_orphan(s, 0)
    s = schedule_purge(s, 0)

    {:noreply, s}
  end

  def handle_info({:clean_orphan_acks}, s) when is_map(s) do
    clean_orphan_acks(s)

    s = schedule_orphan(s)

    {:noreply, s}
  end

  def handle_info({:purge_switch_cmds}, s)
      when is_map(s) do
    purge_sw_cmds(s)

    s = schedule_purge(s)

    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug(fn ->
      ":EXIT message " <> "pid: #{inspect(pid)} reason: #{inspect(reason)}"
    end)

    {:noreply, state}
  end

  #
  ## Private functions
  #

  defp do_code_change(:janitor0001, state, _extra) do
    Map.put(state, :stats, %{})
  end

  defp do_code_change(:janitor0002, state, _extra) do
    Map.put(state, :stats, %{last_purge: Timex.now()})
  end

  # default for code changes that don't require any action
  defp do_code_change(_old_vsn, state, _extra) do
    state
  end

  defp clean_orphan_acks(s) when is_map(s) do
    opts = s.opts.orphan_acks
    {orphans, nil} = SwitchCmd.ack_orphans(opts)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "orphans_acked",
      val: orphans
    )

    if opts.log do
      orphans > 0 && Logger.info(fn -> "orphans ack'ed: [#{orphans}]" end)
    end

    orphans
  end

  defp log_purge(s) do
    s.opts.switch_cmds.log
  end

  defp purge_sw_cmds(s)
       when is_map(s) do
    purged = SwitchCmd.purge_acked_cmds(s.opts.switch_cmds)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "purged_sw_cmd_ack",
      val: purged
    )

    if log_purge(s) do
      purged > 0 &&
        Logger.info(fn ->
          ~s/purged #{purged} acked switch commands/
        end)
    end

    purged
  end

  # handle the situation where the interval has been changed
  defp reschedule_purge(s, new_opts)
       when is_map(s) and is_list(new_opts) do
    asis = s.opts.switch_cmds.interval
    tobe = s.opts.switch_cmds.interval

    if asis != tobe do
      Logger.info(fn -> "rescheduling purge for interval #{tobe}" end)
      reschedule_purge(s)
    else
      s
    end
  end

  defp reschedule_purge(s) do
    timer = Map.get(s, @purge_timer)

    unless timer do
      Process.cancel_timer(timer)
    end

    schedule_purge(s)
  end

  defp schedule_orphan(s) when is_map(s) do
    after_millis = ms(s.opts.orphan_acks.interval)
    schedule_orphan(s, after_millis)
  end

  defp schedule_orphan(s, after_millis) when is_map(s) do
    t = send_after(self(), {:clean_orphan_acks}, after_millis)
    Map.put(s, @orphan_timer, t)
  end

  defp schedule_purge(s)
       when is_map(s) do
    after_millis = ms(s.opts.switch_cmds.interval)
    schedule_purge(s, after_millis)
  end

  defp schedule_purge(s, after_millis)
       when is_map(s) do
    t = send_after(self(), {:purge_switch_cmds}, after_millis)
    Map.put(s, @purge_timer, t)
  end
end
