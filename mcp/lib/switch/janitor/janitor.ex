defmodule Janitor do
  @moduledoc false

  require Logger
  use GenServer
  use Timex

  use Config.Helper
  import Process, only: [send_after: 3]
  import Janice.TimeSupport, only: [duration_ms: 1]

  alias Fact.RunMetric

  defmacro __using__(_opts) do
    quote do
      use Config.Helper
      import Janice.TimeSupport, only: [utc_now: 0]

      def janitor_opts do
        from_config = Application.get_env(:mcp, __MODULE__)

        mods =
          :sys.get_state(unquote(__MODULE__))
          |> Map.get(:mods, %{})

        if Map.has_key?(mods, __MODULE__) do
          Map.get(mods, __MODULE__, %{})
          |> Map.get(:opts, [])
        else
          from_config
        end
      end

      def janitor_opts(new_opts) when is_list(new_opts) do
        GenServer.call(
          unquote(__MODULE__),
          %{action: :update_opts, mod: __MODULE__, opts: new_opts}
        )
      end

      def orphan(%{acked: false} = cmd) do
        {:orphan, update(cmd, acked: true, ack_at: utc_now(), orphan: true)}
      end

      def orphan(%{acked: true} = cmd) do
        {:acked, {:ok, cmd}}
      end

      def orphan_list(opts \\ []) when is_list(opts) do
        import Ecto.Query, only: [from: 2]
        import Janice.TimeSupport, only: [utc_shift_past: 1]

        # sent before passed as an option will override the app env config
        # if not passed in then grab it from the config
        # finally, as a last resort use the hardcoded value
        sent_before_opts =
          Keyword.get(
            opts,
            :sent_before,
            orphan_config(:sent_before, seconds: 31)
          )

        before = utc_shift_past(sent_before_opts)

        from(x in __MODULE__,
          where:
            x.acked == false and x.orphan == false and x.inserted_at <= ^before,
          preload: [:device]
        )
        |> Repo.all()
      end

      #
      ## Config
      #
      def orphan_config(key, defs) when is_atom(key),
        do: config(:orphan) |> Keyword.get(key, defs)

      def purge_config, do: config(:purge)

      #
      # NOTE:
      #   track() and untrack() return the cmd untouched and return the
      #   cmd unchanged
      #

      # NOTE:  callers of this function will receive the map (cmd), unchanged,
      #        as the return value
      def track(%{refid: _refid} = cmd, extra_opts \\ [])
          when is_list(extra_opts) do
        opts = config(:orphan) ++ extra_opts
        msg = {:track, %{cmd: cmd, mod: __MODULE__, opts: opts}}

        if is_nil(GenServer.whereis(unquote(__MODULE__))),
          do: Logger.warn([unquote(__MODULE__), " not started"]),
          else: GenServer.cast(unquote(__MODULE__), msg)

        cmd
      end

      def track_list(cmds) when is_list(cmds) do
        for cmd <- cmds, do: track(cmd)
      end

      # NOTE:  callers of this function will receive whatever was passed
      #        as parameters as the return value
      def untrack({:ok, %{refid: _refid} = cmd} = rc) do
        msg = {:untrack, %{cmd: cmd, mod: __MODULE__, opts: []}}

        if is_nil(GenServer.whereis(unquote(__MODULE__))),
          do: Logger.warn([unquote(__MODULE__), " not started"]),
          else: GenServer.cast(unquote(__MODULE__), msg)

        rc
      end

      # simply pass through anything we haven't pattern matched
      def untrack(anything), do: anything

      def want_janitorial_services, do: __MODULE__
    end
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
  ## GenServer Start Up and Shutdown Callbacks
  #

  def start_link(s) do
    defs = []

    opts = Application.get_env(:mcp, __MODULE__, defs)

    # setup the overall state with the necessary keys so we can pattern
    # match in handle_* functions
    s =
      Map.merge(s, %{
        autostart: Map.get(s, :autostart, false),
        opts: opts,
        tasks: [],
        mods: %{},
        counts:
          for k <- Keyword.get(opts, :metrics_frequency, []) |> Keyword.keys() do
            {count_key(k), 0}
          end,
        opts_vsn: Ecto.UUID.generate(),
        starting_up: true
      })

    GenServer.start_link(Janitor, s, name: Janitor)
  end

  # when autostart is true leverage handle_continue() to complete
  # startup activities
  def init(%{autostart: autostart, opts: _opts} = s) do
    log?(s, :init_args) && Logger.info(["init(): ", inspect(s, pretty: true)])

    if autostart == true do
      Process.flag(:trap_exit, true)

      {:ok, s, {:continue, {:startup}}}
    else
      {:ok, s}
    end
  end

  def terminate(reason, s) do
    log?(s, :init) &&
      Logger.info(["terminating with reason ", inspect(reason, pretty: true)])
  end

  #
  ## GenServer callbacks
  #

  # update Janitor opts
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

  # update module which used Janitor
  def handle_call(
        %{action: :update_opts, mod: update_mod, opts: new_opts},
        _from,
        %{mods: mods, opts: _opts} = s
      ) do
    keys_to_return = Keyword.keys(new_opts)

    with %{track: _, opts: opts} = mod <- Map.get(mods, update_mod),
         new_opts <- DeepMerge.deep_merge(opts, new_opts),
         was_rc <- Keyword.take(opts, keys_to_return),
         is_rc <- Keyword.take(new_opts, keys_to_return),
         mods <- %{
           mods
           | mod => %{mod | opts: new_opts, opts_vsn: Ecto.UUID.generate()}
         } do
      {:reply, {:ok, [was: was_rc, is: is_rc]}, %{s | mods: mods}}
    else
      _anything ->
        {:reply, {:failed, %{mod: update_mod, mods: mods}}}
    end
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
        {:track, %{cmd: _cmd, mod: mod, opts: _opts} = msg},
        %{mods: _mods} = s
      ) do
    {mod_rc, s} = ensure_mod_map(s, mod)

    {:noreply, s, {:continue, {:track, msg, mod_rc}}}
  end

  def handle_cast(
        {:untrack, %{cmd: _cmd, mod: mod, opts: _opts} = msg},
        %{mods: _mods} = s
      ) do
    {mod_rc, s} = ensure_mod_map(s, mod)

    {:noreply, s, {:continue, {:untrack, msg, mod_rc}}}
  end

  def handle_cast(catchall, s) do
    Logger.warn([
      "handle_cast(catchall) unhandled msg: ",
      inspect(catchall, pretty: true)
    ])

    {:noreply, s}
  end

  def handle_continue(
        {:startup},
        %{opts: _opts, mods: _mods, starting_up: true} = s
      ) do
    check_mods = startup_orphan_check_modules()

    log?(s, :init) &&
      Logger.info(["will check ", inspect(check_mods), " for orphans"])

    {:noreply, schedule_metrics(s),
     {:continue, {:startup_orphan_check, check_mods}}}
  end

  def handle_continue(
        {:startup_orphan_check, _empty_list = []},
        %{opts: _opts, mods: _mods, starting_up: true} = s
      ) do
    {:noreply, s, {:continue, {:startup_complete}}}
  end

  def handle_continue(
        {:startup_orphan_check, [check_mod | rest]},
        %{opts: _opts, mods: _mods, starting_up: true} = s
      )
      when is_atom(check_mod) do
    #
    # invoke the module to generate a possible orphan list
    orphans =
      apply(check_mod, :orphan_list, [])
      |> log_startup_possible_orphans(check_mod, s)

    apply(check_mod, :track_list, [orphans])

    {:noreply, s, {:continue, {:startup_orphan_check, rest}}}
  end

  def handle_continue({:startup_complete}, %{starting_up: true} = s) do
    log?(s, :init) && Logger.info(["startup complete"])
    {:noreply, %{s | starting_up: false}}
  end

  def handle_continue(
        {:track, %{cmd: %{refid: refid} = cmd, mod: mod, opts: opts}, :mod_ok},
        %{mods: mods} = s
      ) do
    #
    # pattern match the state for the module for this refid
    %{track: track} = mod_map = Map.get(mods, mod)

    # this function expects to find sent_before: [key: val] in opts
    # get the key and convert it to milliseconds via TimeSupport
    orphan_timeout_ms =
      Keyword.get(opts, :sent_before, [])
      |> duration_ms()

    if orphan_timeout_ms > 0 do
      Process.send_after(
        self(),
        {:possible_orphan, mod, refid},
        orphan_timeout_ms
      )

      track = Map.put(track, refid, %{cmd: cmd, opts: opts})

      s = %{s | mods: %{mods | mod => %{mod_map | track: track}}}

      {:noreply, increment_count({:switch_cmd, nil}, s)}
    else
      Logger.warn([
        "handle_cast(:track) could not determine orphan timeout for ",
        inspect(mod),
        " from opts: ",
        inspect(opts, pretty: true)
      ])

      # don't add the refid id to track list since no message was queued
      {:noreply, increment_count({:switch_cmd, nil}, s)}
    end
  end

  def handle_continue(
        {:untrack, %{cmd: %{refid: refid} = _cmd, mod: mod, opts: _opts},
         :mod_ok},
        %{mods: mods} = s
      ) do
    #
    # pattern match the state for the module for this refid
    %{track: track} = mod_map = Map.get(mods, mod)

    {:noreply,
     %{s | mods: %{mods | mod => %{mod_map | track: Map.delete(track, refid)}}}}
  end

  # the module was not found in the Janitor's state
  def handle_continue({action, msg, :error}, s)
      when action in [:track, :untrack] do
    Logger.error([
      "handle_continue(",
      inspect(action),
      ", ",
      inspect(msg, pretty: true),
      ")"
    ])

    {:noreply, s}
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
  #   the track map (because untrack was invoked) this is not an orphan
  #
  #   if refid was found in the track map then this cmd is POSSIBLY an
  #   orphan so invoke the possible_orphan() function for a final decision
  def handle_info(
        {:possible_orphan, mod, refid},
        %{mods: mods} = s
      ) do
    #
    # pattern match the state for the module for this refid
    # Logger.info([":possible_orphan mods: ", inspect(mods, pretty: true)])
    %{opts: _opts, track: track} = mod_map = Map.get(mods, mod)

    tracked = Map.get(track, refid, :not_tracked)

    with {:refid, tracked} when is_map(tracked) <- {:refid, tracked},
         # pattern match out the cmd and opts from the tracked refid
         %{cmd: cmd, opts: opts} <- tracked,
         # delete the tracked refid from the tracker map
         # NOTE: Map.delete/2 is a noop if key doesn't exist
         track <- Map.delete(track, refid),
         # put the updated tracker map into the module's map
         mod_map <- Map.put(mod_map, :track, track),
         # perform the actual orphan check and log the results
         orphan_rc <- apply(mod, :orphan, [cmd]) |> log_orphan_rc(opts),
         # update the states's orphan counts (if needed) and module map
         new_state <- increment_count(orphan_rc, s) |> Map.put(mod, mod_map) do
      {:noreply, new_state}
    else
      {:refid, :not_tracked} ->
        {:noreply, s}
    end
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

  defp ensure_mod_map(%{mods: mods} = s, mod) do
    with {:mod_known, false} <- {:mod_known, Map.has_key?(mods, mod)},
         mods_now <- make_mod_maps(),
         {:mod_new, true} <- {:mod_new, Map.has_key?(mods_now, mod)},
         mods <- Map.put(mods, mod, Map.get(mods_now, mod)) do
      {:mod_ok, %{s | mods: mods}}
    else
      {:mod_known, true} ->
        {:mod_ok, s}

      {:mod_new, false} ->
        Logger.error(["module ", inspect(mod), " did not use Janitor"])
        {:error, s}
    end
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

  defp make_mod_maps do
    {:ok, all_mods} = :application.get_key(:mcp, :modules)

    for m <- all_mods,
        function_exported?(m, :want_janitorial_services, 0),
        into: %{} do
      {m,
       %{
         opts: [
           orphan: apply(m, :config, [:orphan]),
           purge: apply(m, :config, [:purge])
         ],
         opts_vsn: Ecto.UUID.generate(),
         track: %{}
       }}
    end
  end

  defp schedule_metrics(
         %{opts: opts, opts_vsn: opts_vsn, starting_up: startup} = s,
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

  defp startup_orphan_check_modules do
    has_config? = fn
      x when is_list(x) -> get_in(x, [:orphan, :at_startup])
      _x -> false
    end

    for {k, v} <- Application.get_all_env(:mcp),
        is_list(v),
        has_config?.(v),
        do: k
  end

  #
  ## Logging Helpers
  #
  def log_orphan_rc(orphan_rc, opts) when is_list(opts) do
    log = get_in(opts, [:orphan, :log]) || false

    case orphan_rc do
      {:orphan, {:ok, %{refid: refid}}} ->
        log &&
          Logger.warn([
            "orphaned refid ",
            inspect(refid, pretty: true)
          ])

      {:orphan, {_, %{}} = cmd_rc} ->
        Logger.warn([
          "orphaned with a problem:  ",
          inspect(cmd_rc, pretty: true)
        ])

      {:acked, _cmd_rc} ->
        # command was already ack'ed, nothing to log
        true

      anything ->
        Logger.warn([
          "unhandled rc: ",
          inspect(anything, pretty: true)
        ])
    end

    orphan_rc
  end

  defp log_startup_possible_orphans(orphans, check_mod, %{opts: _opts} = s)
       when is_list(orphans) do
    orphan_count = Enum.count(orphans)

    cond do
      orphan_count > 0 ->
        log?(s, :init) && orphan_count > 0 &&
          Logger.info([
            "detected ",
            inspect(orphan_count),
            " possible orphan(s) for ",
            inspect(check_mod)
          ])

      orphan_count == 0 ->
        Logger.info([
          "no orphans detected for ",
          inspect(check_mod)
        ])

      true ->
        true
    end

    # return the orphans passed in for pipeline use
    orphans
  end

  defp log_startup_possible_orphans(anything, check_mod, %{opts: _opts} = s) do
    log?(s, :init) &&
      Logger.warn([
        inspect(check_mod),
        " should be an orphan list: ",
        inspect(anything, pretty: true)
      ])

    # return an empty list to prevent pipeline failure
    []
  end
end
