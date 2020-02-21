defmodule Dutycycle.Server do
  @moduledoc false

  require Logger
  use GenServer

  alias Dutycycle.Profile

  ####
  #### API
  ####

  def add(list) when is_list(list) do
    for x <- list, do: add(x)
  end

  def add(x) do
    case Dutycycle.add(x) do
      %Dutycycle{id: id, name: name, log: log} ->
        log &&
          Logger.info([
            "added ",
            inspect(name, pretty: true),
            " (id: ",
            inspect(id, pretty: true),
            ")"
          ])

        Dutycycle.Supervisor.start_child(
          child_spec(%{id: id, added: true, log: log})
        )

      {:invalid_changes, cs} = rc ->
        Logger.warn([
          "add failed due to invalid changes ",
          "args: ",
          inspect(x, pretty: true),
          "rc: ",
          inspect(cs, pretty: true)
        ])

        rc

      rc ->
        Logger.warn([
          "add failed",
          "args: ",
          inspect(x, pretty: true),
          "rc: ",
          inspect(rc, pretty: true)
        ])

        rc
    end
  end

  def active?(name, opts \\ []) when is_binary(name) and is_list(opts),
    do:
      %{name: name, msg: %{msg: :active?, opts: opts}}
      |> call_server()

  def activate_profile(name, profile_name, opts \\ [])
      when is_binary(name) and is_binary(profile_name) and is_list(opts) do
    {rc, res} =
      %{
        name: name,
        msg: %{msg: :activate_profile, profile: profile_name, opts: opts}
      }
      |> call_server()

    {rc, Dutycycle.status(res)}
  end

  def add_profile(name, %Profile{} = p, opts \\ [])
      when is_binary(name) and is_list(opts),
      do:
        %{name: name, msg: %{msg: :add_profile, profile: p, opts: opts}}
        |> call_server()

  def all(:dutycycles) do
    servers = Dutycycle.Supervisor.known_servers()

    for {s, _pid} <- servers,
        d = Dutycycle.Server.dutycycle(s),
        is_map(d),
        do: d
  end

  def all(:names) do
    servers = Dutycycle.Supervisor.known_servers()

    for {s, _pid} <- servers,
        d = Dutycycle.Server.dutycycle(s),
        is_map(d),
        do: d.name
  end

  def all(:as_maps), do: all(:dutycycles)

  def change_device(name, new_device)
      when is_binary(name) and is_binary(new_device),
      do:
        %{name: name, msg: %{msg: :change_device, new_device: new_device}}
        |> call_server()

  def delete(name) when is_binary(name), do: Dutycycle.delete(name)

  def delete(%Dutycycle{} = dc) do
    if Dutycycle.Supervisor.ping() == :pong,
      do: Dutycycle.Supervisor.eliminate_child(server_name_atom(dc)),
      else: :no_supervisor
  end

  def delete_profile(name, profile, opts \\ [])
      when is_binary(name) and
             is_binary(profile),
      do:
        %{
          name: name,
          msg: %{msg: :delete_profile, profile: profile, opts: opts}
        }
        |> call_server()

  def dutycycle(x, opts \\ [])

  def dutycycle(name, opts) when is_binary(name),
    do: %{name: name, msg: %{msg: :dutycycle, opts: opts}} |> call_server()

  def dutycycle(server_name, opts) when is_atom(server_name) do
    msg = %{:msg => :dutycycle, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
  end

  def dutycycle_state(name, opts \\ [])
      when is_binary(name) and is_list(opts),
      do:
        %{name: name, msg: %{msg: :dutycycle_state, opts: opts}}
        |> call_server()

  def halt(name, opts \\ []) when is_binary(name),
    do:
      %{name: name, msg: %{msg: :halt, opts: opts}}
      |> call_server()

  def log(name, opts \\ []) when is_binary(name),
    do: %{name: name, msg: %{msg: :log, opts: opts}} |> call_server()

  def pause(name, opts \\ []) when is_binary(name), do: halt(name, opts)

  def ping(name, opts \\ []) when is_binary(name),
    do:
      %{name: name, msg: %{msg: :ping, opts: opts}}
      |> call_server()

  def profiles(name, opts \\ []) when is_binary(name) and is_list(opts),
    do:
      %{name: name, msg: %{msg: :profiles, opts: opts}}
      |> call_server()

  def reload(name, opts \\ []) when is_binary(name) and is_list(opts),
    do:
      %{name: name, msg: %{msg: :reload, opts: opts}}
      |> call_server()

  def resume(name, opts \\ []) when is_binary(name) and is_list(opts),
    # special case for resume -> request activation of the :active profile
    do:
      %{
        name: name,
        msg: %{msg: :activate_profile, profile: :active, opts: opts}
      }
      |> call_server()

  def restart(name) when is_binary(name),
    do: Dutycycle.Supervisor.restart_dutycycle(name)

  def standby(name, opts \\ []) when is_binary(name), do: halt(name, opts)

  def switch_state(name, opts \\ []) when is_binary(name),
    do:
      %{name: name, msg: %{:msg => :switch_state, opts: opts}}
      |> call_server()

  def update(name, opts) when is_binary(name) and is_list(opts),
    do:
      %{name: name, msg: %{msg: :update, opts: opts}}
      |> call_server()

  def update(_catchall), do: Logger.warn("update(dutycycle_name, opts")

  def update_profile(name, profile, opts)
      when is_binary(name) and is_binary(profile) and is_list(opts) do
    msg = %{msg: :update_profile, profile: profile, opts: opts}

    %{profile: {rc, res}, reload: reload} = call_server(name, msg)

    # if the change was successful and it was to the active profile then
    # then re-activate the profile to effectuate the changes made
    if rc == :ok do
      dc = dutycycle(name)

      reload && Dutycycle.active?(dc) && Profile.active?(res) &&
        activate_profile(name, Profile.name(res))
    end

    %{profile: {rc, res}, reload: reload}
  end

  ####
  #### GENSERVER MESSAGE HANDLERS
  ####

  def handle_call(
        %{msg: :activate_profile, profile: profile, opts: opts} = msg,
        _from,
        s
      ) do
    delay_ms = Keyword.get(opts, :delay_ms, 0)

    if delay_ms == 0 do
      {rc, s} = actual_activate_profile(msg, s)

      {:reply, rc, s}
    else
      {rc, s} =
        activate_profile_delayed(s, %{profile: profile, delay_ms: delay_ms})

      {:reply, rc, s}
    end
  end

  def handle_call(%{msg: :add_profile, profile: p}, _from, s) do
    rc = Profile.add(s.dutycycle, p)

    s = need_reload(s, reload: true) |> reload_dutycycle()

    {:reply, rc, s}
  end

  def handle_call(
        %{msg: :delete_profile, profile: profile, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = need_reload(s, opts)

    {rc, res} = Dutycycle.delete_profile(dc, profile, opts)

    {:reply, {rc, res}, cache_dutycycle(s)}
  end

  def handle_call(
        %{msg: :dutycycle, opts: _opts},
        _from,
        %{dutycycle: dc} = s
      ),
      do: {:reply, dc, s}

  def handle_call(
        %{msg: :dutycycle_state, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    {%Dutycycle{} = dc, %Dutycycle.State{} = st} =
      Dutycycle.current_state(dc, opts)

    # the caller may have requested a reload
    # so cache the returned dutycycle
    # if reload wasn't requested this is essentially a nop
    {:reply, st, cache_dutycycle(dc, s)}
  end

  def handle_call(
        %{msg: :change_device, new_device: new_device},
        _from,
        %{dutycycle: dc} = s
      ) do
    rc = Dutycycle.device_change(dc, new_device)

    case rc do
      {:error, _} ->
        {:reply, rc, s}

      {:invalid_changes} ->
        {:reply, rc, s}

      {:ok, dc} ->
        {:reply, :ok, %{s | dutycycle: dc}}

      rc ->
        Logger.warn(fn -> "unmatched change_device result" end)
        Logger.warn(fn -> "#{inspect(rc, pretty: true)}" end)
        {:reply, :internal_error, s}
    end
  end

  def handle_call(%{msg: :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(
        %{msg: :profiles, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ),
      do: {:reply, Dutycycle.profiles(dc, opts), s}

  def handle_call(%{:msg => :reload, :opts => opts}, _from, s) do
    log_reload = Keyword.get(opts, :log_reload, false)

    s = need_reload(s, reload: true) |> Map.put_new(:log_reload, log_reload)

    {:reply, :reload_queued, s}
  end

  def handle_call(
        %{msg: :halt, opts: _opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = cancel_timer(s, :all)
    rc = Dutycycle.halt(dc)

    {:reply, rc, cache_dutycycle(s)}
  end

  def handle_call(
        %{msg: :log, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    rc = Dutycycle.log(dc, opts)

    {:reply, rc, cache_dutycycle(s)}
  end

  def handle_call(
        %{msg: :switch_state, opts: _opts},
        _from,
        %{dutycycle: %Dutycycle{device: device}} = s
      ) do
    state = Switch.position(device)

    {:reply, state, s}
  end

  def handle_call(
        %{msg: :active?, opts: _opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    {:reply, Dutycycle.active?(dc), s}
  end

  def handle_call(
        %{msg: :update, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = need_reload(s, opts)

    # process the actual changes to the profile
    {rc, res} = Dutycycle.update(dc, opts)

    {:reply, %{dutycycle: {rc, res}, reload: need_reload?(s)},
     cache_dutycycle(s)}
  end

  def handle_call(
        %{msg: :update_profile, profile: profile, opts: opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = need_reload(s, opts)
    # process the actual changes to the profile
    {rc, res} = Profile.change_properties(dc, profile, opts)

    {:reply, %{profile: {rc, res}, reload: need_reload?(s)},
     reload_dutycycle(s)}
  end

  # handle case when we receive a message that we don't understand
  def handle_call(%{msg: _unhandled} = msg, _from, %{dutycycle: dc} = s) do
    Logger.warn(fn ->
      "unhandled message\n" <>
        inspect(msg, pretty: true) <>
        "\n" <>
        inspect(dc, pretty: true)
    end)

    {:reply, :unhandled_msg, s}
  end

  !def handle_info(
         %{msg: :activate_profile} = msg,
         %{} = s
       ) do
    {_rc, s} = actual_activate_profile(msg, s)

    {:noreply, s}
  end

  def handle_info(
        %{msg: :phase_end, profile: profile, ms: _ms},
        %{dutycycle: dc} = s
      )
      when is_binary(profile) do
    with true <- Profile.active?(dc, profile),
         {:ok, dc, _active_profile, _mode} = rc <- Dutycycle.end_of_phase(dc),
         %{dutycycle_id: _id} = s <-
           %{s | dutycycle: dc} |> start_phase_timer(rc) do
      {:noreply, cache_dutycycle(s)}
    else
      false ->
        active_profile = Profile.active(dc)

        Logger.warn(fn ->
          "#{inspect(dc.name)}" <>
            " phase end timer for #{inspect(profile, pretty: true)} does not" <>
            " match active profile #{inspect(active_profile, pretty: true)}, ignored"
        end)

        {:noreply, s}

      error ->
        Logger.warn(fn ->
          "phase_end(): " <>
            "#{inspect(error, pretty: true)}"
        end)

        {:noreply, s}
    end
  end

  def handle_info(%{msg: :scheduled_work}, %{server_name: server_name} = s) do
    s = %{dutycycle: dc} = reload_dutycycle(s)

    Process.send_after(
      server_name,
      %{:msg => :scheduled_work},
      Dutycycle.scheduled_work_ms(dc)
    )

    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, %{dutycycle: dc} = s) do
    if reason == :normal do
      {{:stop, :normal}, s}
    else
      Logger.warn(fn ->
        ":EXIT #{inspect(dc.name)} message pid: #{inspect(pid, pretty: true)} reason: #{
          inspect(reason, pretty: true)
        }"
      end)

      {{:stop, reason}, s}
    end
  end

  ####
  #### GENSERVER BASE FUNCTIONS
  ####

  def child_spec(%{id: id, log: log} = args) do
    {dutycycle, server_name} = server_name(id)
    args = Map.put(args, :dutycycle, dutycycle)

    if is_nil(dutycycle),
      do: %{},
      else: %{
        id: server_name,
        start: {Dutycycle.Server, :start_link, [args]},
        restart: :permanent,
        shutdown: 10_000,
        log: log
      }
  end

  def start_link(%{id: id} = args) do
    Logger.debug(fn -> "start_link() args: #{inspect(args, pretty: true)}" end)

    opts = Application.get_env(:mcp, Dutycycle.Server, [])
    {dc, server_name} = server_name(id)

    GenServer.start_link(
      __MODULE__,
      %{
        server_name: server_name,
        opts: opts,
        dutycycle_id: id,
        # call Dutycycle.reload() to ensure all associations are preloaded
        dutycycle: Dutycycle.reload(dc),
        timers: [],
        need_reload: false,
        startup_delay_ms: 15_000
      }
      |> Map.merge(args),
      name: server_name
    )
  end

  def init(
        %{
          server_name: server_name,
          dutycycle: %Dutycycle{startup_delay_ms: activate_delay_ms} = dc
        } = s
      ) do
    Process.flag(:trap_exit, true)

    Process.send_after(
      server_name,
      %{:msg => :scheduled_work},
      Dutycycle.scheduled_work_ms(dc)
    )

    # case statement determines return value
    case Dutycycle.start(dc) do
      {:ok, :inactive} ->
        {:ok, s}

      {:ok, :run, profile} ->
        {_rc, s} =
          activate_profile_delayed(s, %{
            profile: profile,
            delay_ms: activate_delay_ms
          })

        {:ok, s}

      rc ->
        Logger.warn("start() returned:\n#{inspect(rc, pretty: true)}")
        {:ok, s}
    end
  end

  def terminate(reason, %{dutycycle: %Dutycycle{name: name, log: log} = dc}) do
    log &&
      Logger.info(
        inspect(name, pretty: true) <>
          " terminating, reason #{inspect(reason, pretty: true)}"
      )

    Dutycycle.shutdown(dc)
  end

  ####
  #### PRIVATE FUNCTIONS
  ####

  defp activate_profile_delayed(
         %{
           server_name: server_name,
           dutycycle: %Dutycycle{name: name, log: log} = dc,
           timers: timers
         } = s,
         %{
           profile: profile,
           delay_ms: delay_ms
         }
       ) do
    timer =
      Process.send_after(
        server_name,
        %{:msg => :activate_profile, profile: profile, opts: []},
        delay_ms
      )

    log &&
      Logger.info(
        "#{inspect(name)} profile #{
          inspect(Profile.name(profile), pretty: true)
        }" <>
          " will activate in #{inspect(delay_ms)}ms"
      )

    {{:ok, dc},
     %{s | timers: Keyword.put(timers, :delayed_activate_timer, timer)}}
  end

  defp actual_activate_profile(
         %{msg: :activate_profile, profile: profile, opts: _opts},
         %{dutycycle: dc} = s
       ) do
    rc = Dutycycle.activate_profile(dc, profile)
    s = cache_dutycycle(s) |> cancel_timer(:delayed_activate_timer)

    case rc do
      {:ok, %Dutycycle{name: name, log: log} = dc, %Profile{name: profile_name},
       :run} ->
        log &&
          Logger.info(
            "#{inspect(name)} profile #{inspect(profile_name)} activated"
          )

        {{:ok, dc},
         cancel_timer(s, :phase_timer)
         |> start_phase_timer(rc)
         |> cache_dutycycle()}

      {:ok, %Dutycycle{} = dc, %Profile{}, :none} ->
        {{:ok, dc}, cancel_timer(s, :phase_timer) |> cache_dutycycle()}

      rc ->
        {{:failed, rc}, s}
    end

    # case statement above returns {result, state}
  end

  # when called with just the state do a reload of the dutycycle
  # and cache it
  defp cache_dutycycle(%{dutycycle: dc} = s),
    do: cache_dutycycle(Dutycycle.reload(dc), s)

  # when called with a Dutycycle and the state
  # just cache the Dutycycle passed in
  defp cache_dutycycle(%Dutycycle{} = dc, %{dutycycle: _dc} = s),
    do: %{s | dutycycle: dc}

  defp call_server(%{name: name, msg: %{} = msg}), do: call_server(name, msg)

  defp call_server(name, msg) when is_binary(name) and is_map(msg) do
    {dc, server_name} = server_name(name)

    msg = Map.put(msg, :dutycycle, dc)
    pid = Process.whereis(server_name)

    cond do
      is_nil(dc) -> :not_found
      is_pid(pid) -> GenServer.call(server_name, msg)
      true -> :no_server
    end
  end

  defp cancel_timer(%{timers: timers} = s, timer)
       when is_list(timers) and is_atom(timer) do
    timers =
      case timer do
        :all ->
          for {k, v} <- timers do
            if is_reference(v), do: Process.cancel_timer(v)
            {k, nil}
          end

        x ->
          t = Keyword.get(timers, x)
          if is_reference(t), do: Process.cancel_timer(t)
          Keyword.put(timers, x, nil)
      end

    %{s | timers: timers}
  end

  defp cancel_timer(%{} = s, _timer), do: %{s | timers: []}

  # if the key reload is persent in the opts then add it to the state
  # however defaults to true
  defp need_reload(%{} = s, opts) when is_list(opts),
    do: %{s | need_reload: Keyword.get(opts, :reload, true)}

  defp need_reload?(%{need_reload: reload}), do: reload

  # Refactor
  defp start_phase_timer(
         %{server_name: server, timers: timers} = s,
         {:ok, %Dutycycle{} = dc, %Profile{run_ms: ms} = p, :run}
       ) do
    msg = %{:msg => :phase_end, :profile => Profile.name(p), :ms => ms}
    t = Process.send_after(server, msg, ms)

    _dc = Dutycycle.persist_phase_end_timer(dc, t)

    # return an updated state
    %{s | timers: Keyword.put(timers, :phase_timer, t)}
  end

  # Refactor
  defp start_phase_timer(
         %{server_name: server, timers: timers} = s,
         {:ok, %Dutycycle{} = dc, %Profile{idle_ms: ms} = p, :idle}
       ) do
    msg = %{:msg => :phase_end, :profile => Profile.name(p), :ms => ms}
    t = Process.send_after(server, msg, ms)

    _dc = Dutycycle.persist_phase_end_timer(dc, t)

    # return an updated state
    %{s | timers: Keyword.put(timers, :phase_timer, t)}
  end

  # Refactor
  # handle the special case of 'none' profile
  #  a. run_ms = 0
  #  b. idle_ms = 0
  #  c. name === "none"
  defp start_phase_timer(
         %{server_name: _server, timers: timers} = s,
         {:ok, %Dutycycle{}, %Profile{run_ms: 0, idle_ms: 0, name: "none"},
          _mode}
       ),
       do: %{s | timers: Keyword.put(timers, :phase_timer, nil)}

  # Refactor
  defp start_phase_timer(%{} = s, rc) do
    Logger.warn(fn ->
      "start_phase_timer received #{inspect(rc, pretty: true)} end"
    end)

    s
  end

  defp reload_dutycycle(
         %{dutycycle: %Dutycycle{name: name, id: id} = dc, need_reload: true} =
           s
       ) do
    dc = Dutycycle.reload(dc)
    log = Map.get(s, :log_reload, false)

    if is_nil(dc) do
      Logger.warn(fn ->
        "dutycycle id=#{inspect(id, pretty: true)} reload failed"
      end)

      s
    else
      log && Logger.info(fn -> "#{inspect(name)} reloaded" end)
      Map.merge(s, %{need_reload: false, dutycycle: dc})
    end
  end

  defp reload_dutycycle(%{} = s), do: s

  def server_name(x) when is_binary(x) or is_integer(x) do
    dc = Dutycycle.find(x)

    if is_nil(dc), do: {nil, nil}, else: {dc, server_name_atom(dc)}
  end

  defp server_name_atom(%{id: _} = dc),
    do: Dutycycle.Supervisor.server_name_atom(dc)

  defp server_name_atom(_), do: :no_server
end
