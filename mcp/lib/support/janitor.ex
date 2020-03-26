defmodule Janitor do
  @moduledoc false

  require Logger
  use GenServer
  use Timex

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]
  import Janice.TimeSupport, only: [duration_ms: 1]

  alias Fact.RunMetric

  defmacro __using__(_opts) do
  end

  #
  ## Public API
  #

  def counts(opts \\ []) when is_list(opts) do
    GenServer.call(__MODULE__, {:counts, opts})
  end

  def empty_trash(trash, opts \\ []) when is_list(trash) and is_list(opts) do
    GenServer.cast(__MODULE__, {:empty_trash, trash, opts})
  end

  def opts, do: :sys.get_state(__MODULE__) |> Map.get(:opts, [])

  def opts(new_opts) when is_list(new_opts) do
    GenServer.call(__MODULE__, %{
      action: :update_opts,
      opts: new_opts
    })
  end

  #
  # NOTE:
  #   track() and untrack() return the cmd untouched and return the
  #   cmd unchanged
  #

  # NOTE:  callers of this function will receive the map (cmd), unchanged,
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

  # simply pass through anything we haven't pattern matched
  def untrack(anything), do: anything

  #
  ## GenServer Start Up and Shutdown Callbacks
  #

  def start_link(s) do
    defs = [
      at_startup: [],
      log: [init: true],
      metrics_frequency: [orphan: [minutes: 5], switch_cmd: [minutes: 5]],
      orphan_acks: [interval: {:mins, 1}, older_than: {:mins, 5}, log: true],
      switch_cmds: [
        purge: true,
        interval: {:mins, 5},
        older_than: {:days, 7},
        log: true
      ]
    ]

    opts = get_env(:mcp, Janitor, defs)

    # setup the overall state with the necessary keys so we can pattern
    # match in handle_* functions
    s =
      Map.merge(s, %{
        autostart: Map.get(s, :autostart, false),
        opts: opts,
        track: %{},
        tasks: [],
        counts:
          for k <- Keyword.get(opts, :metrics_frequency, []) |> Keyword.keys() do
            {count_key(k), 0}
          end,
        opts_vsn: Ecto.UUID.generate()
      })

    GenServer.start_link(Janitor, s, name: Janitor)
  end

  # when autostart is true leverage handle_continue() to complete
  # startup activities
  def init(%{autostart: autostart, opts: opts} = s) do
    log = get_in(opts, [:log, :init]) || false

    log && Logger.info(["init(): ", inspect(s, pretty: true)])

    if autostart == true,
      do: {:ok, Map.put(s, :startup, true), {:continue, {:startup}}},
      else: {:ok, s}
  end

  def terminate(reason, _state) do
    Logger.info(["terminating with reason ", inspect(reason, pretty: true)])
  end

  #
  ## GenServer callbacks
  #

  def handle_call(
        %{action: :update_opts, opts: new_opts},
        _from,
        %{opts: opts} = s
      ) do
    keys_to_return = Keyword.keys(new_opts)
    new_opts = DeepMerge.deep_merge(opts, new_opts)

    was_rc = Keyword.take(opts, keys_to_return)
    is_rc = Keyword.take(new_opts, keys_to_return)

    {:reply, {:ok, [was: was_rc, is: is_rc]},
     %{s | opts: new_opts, opts_vsn: Ecto.UUID.generate()}}
  end

  def handle_call({:counts, _opts}, _from, %{counts: counts} = s),
    do: {:reply, counts, s}

  def handle_cast({:empty_trash, trash, opts}, %{tasks: tasks} = s) do
    empty_trash = fn ->
      mod = Keyword.get(opts, :mod, nil)

      {elapsed, results} =
        Duration.measure(fn ->
          for %{id: _} = x <- trash do
            Repo.delete(x)
          end
        end)

      {:trash, mod, elapsed, results}
    end

    task = Task.async(empty_trash)

    tasks = [task] ++ tasks

    {:noreply, %{s | tasks: tasks}}
  end

  def handle_cast(
        {:track, %{refid: refid} = cmd, opts},
        %{track: track} = s
      ) do
    # Janitor expects a Keyword list of options with the key :orphan
    orphan_opts = Keyword.get(opts, :orphan, [])

    # this function expects to find sent_before: [key: val] in opts
    # get the key and convert it to milliseconds via TimeSupport
    orphan_timeout_ms =
      Keyword.get(orphan_opts, :sent_before, [])
      |> duration_ms()

    if orphan_timeout_ms > 0 do
      Process.send_after(self(), {:possible_orphan, refid}, orphan_timeout_ms)
      track = Map.put(track, refid, %{cmd: cmd, opts: opts})

      {:noreply,
       increment_count({:switch_cmd, nil}, s) |> Map.put(:track, track)}
    else
      Logger.warn([
        "handle_cast(:track) could not determine orphan timeout from opts: ",
        inspect(opts, pretty: true)
      ])

      # don't add the refid id to track list since no message was queued
      {:noreply, increment_count({:switch_cmd, nil}, s)}
    end
  end

  def handle_cast(
        {:untrack, %{refid: refid} = _cmd},
        %{track: track} = s
      ) do
    track = Map.delete(track, refid)

    {:noreply, Map.put(s, :track, track)}
  end

  def handle_continue({:startup}, %{opts: _opts, startup: true} = s) do
    Process.flag(:trap_exit, true)

    {:noreply, s |> schedule_metrics() |> Map.put(:startup, false)}
  end

  def handle_continue(catchall, s) do
    Logger.warn(["handle_continue(catchall): ", inspect(catchall, pretty: true)])

    {:noreply, s}
  end

  def handle_info(
        {:metrics, metric, msg_opts_vsn},
        %{opts_vsn: opts_vsn, counts: counts} = s
      ) do
    if msg_opts_vsn == opts_vsn do
      count_key = count_key(metric)

      RunMetric.record(
        module: "#{__MODULE__}",
        metric: count_key,
        val: Keyword.get(counts, count_key, 0)
      )
    end

    s = schedule_metrics(s, metric)

    {:noreply, s}
  end

  # NOTE:
  #   Janitor will receive an info message for EVERY tracked cmd after the
  #   configured orphan timeout has expired.  if the refid is not found in
  #   the track map then untrack was invoked and this is not an orphan
  #
  #   if refid was found in the track map then this cmd is POSSIBLY an
  #   orphan so invoke the possible_orphan() function for a final decision
  def handle_info(
        {:possible_orphan, refid},
        %{track: track} = s
      ) do
    #
    # NOTE: Map.delete/2 silently returns an unchanged map if the requested
    #       key does not exist

    {:noreply,
     possible_orphan(Map.get(track, refid, :not_found), refid)
     |> increment_count(s)
     |> Map.put(:track, Map.delete(track, refid))}
  end

  # quietly handle processes that :EXIT normally
  def handle_info({:EXIT, pid, :normal}, %{tasks: tasks} = s) do
    tasks =
      Enum.reject(tasks, fn
        %Task{pid: search_pid} -> search_pid == pid
        _x -> false
      end)

    {:noreply, %{s | tasks: tasks}}
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

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, s) do
    # normal exit of a process
    {:noreply, s}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, _reason} = msg,
        %{} = s
      )
      when is_reference(ref) and is_pid(pid) do
    Logger.debug([
      "handle_info({:DOWN, ...} msg: ",
      inspect(msg, pretty: true),
      " state: ",
      inspect(s, pretty: true)
    ])

    {:noreply, s}
  end

  def handle_info({_ref, {:trash, mod, _elapsed, results} = msg}, %{} = s) do
    if is_nil(mod) or is_binary(mod) do
      Logger.info([
        "empty_trash() mod: ",
        inspect(mod),
        " count: ",
        inspect(length(results))
      ])
    else
      # if mod is an alive GenServer then cast the message to report the results
      if is_nil(GenServer.whereis(mod)),
        do: false,
        else: GenServer.cast(mod, msg)
    end

    {:noreply, s}
  end

  def handle_info(catchall, s) do
    Logger.warn(["handle_info(catchall): ", inspect(catchall, pretty: true)])
    {:noreply, s}
  end

  #
  ## Private functions
  #

  defp count_key(type) when is_atom(type) do
    [Atom.to_string(type), "_count"]
    |> IO.iodata_to_binary()
    |> String.to_atom()
  end

  defp increment_count(msg, state, amount \\ 1)

  # use the type passed to create a key and update the count
  defp increment_count({type, _res}, %{counts: counts} = s, amount)
       when type in [:orphan, :switch_cmd] and is_integer(amount) do
    count_key = count_key(type)
    new_count = Keyword.get(counts, count_key, 0) + amount

    %{s | counts: Keyword.replace!(counts, count_key, new_count)}
  end

  # handle unknown count keys
  defp increment_count({_rc, _res}, s, _orphans), do: s

  # Janitor will never make a final decision if a cmd is an orphan.  rather,
  # the owning module makes the decision.
  defp possible_orphan(%{cmd: %{refid: refid} = cmd, opts: opts}, _refid) do
    log = get_in(opts, [:orphan, :log]) || false

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

  defp schedule_metrics(
         %{opts: opts, opts_vsn: opts_vsn, startup: startup} = s,
         metric \\ :all
       ) do
    #
    # this function is invoked in two scenarios:
    #  1. at startup to schedule all configured metric reporting
    #  2. when each metric is reported to schedule the next report
    #
    metrics =
      if metric == :all,
        do: Keyword.get(opts, :metrics_frequency, []),
        else:
          Keyword.get(opts, :metrics_frequency, []) |> Keyword.take([metric])

    for {metric, duration_opts} <- metrics do
      millis =
        if startup,
          do: 0,
          else: duration_ms(duration_opts)

      send_after(self(), {:metrics, metric, opts_vsn}, millis)
    end

    s
  end
end

# schedule_orphan/1
#
# queues a clean orphan ack message for send after the duration specified
# in opts.
#
# NOTE: the opts vsn stored in the state is included in the message.
#       this allows for pattern matching when the message is received.
#       specificially, if the opts vsn in the message doesn't match the
#       opts vsn in the state then the message can be quietly ignored
#       because it was scheduled before the latest opts were set.
# defp schedule_orphan(%{opts: opts, opts_vsn: opts_vsn, startup: startup} = s) do
#   millis =
#     if startup,
#       do: 0,
#       else: get_in(opts, [:orphan_acks, :interval]) |> duration_ms()
#
#   send_after(self(), {:clean_orphan_acks, opts_vsn}, millis)
#
#   s
# end
#
# defp schedule_purge(%{opts: opts, opts_vsn: opts_vsn, startup: startup} = s) do
#   # when purge is true schedule the next purge
#   if get_in(opts, [:switch_cmds, :purge]) do
#     millis =
#       if startup,
#         do: 0,
#         else: get_in(opts, [:switch_cmds, :interval]) |> duration_ms()
#
#     send_after(self(), {:purge_switch_cmds, opts_vsn}, millis)
#   end
#
#   s
# end
