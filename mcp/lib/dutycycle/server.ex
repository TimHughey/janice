defmodule Dutycycle.Server do
  @moduledoc false

  require Logger
  use GenServer

  alias Dutycycle.Profile

  ####
  #### API
  ####

  # function header for optional "opts" parameter
  def activate_profile(name, profile_name, opts \\ [])

  def activate_profile(name, profile_name, opts)
      when is_binary(name) and is_binary(profile_name) do
    msg = %{:msg => :activate_profile, profile: profile_name, opts: opts}
    call_server(name, msg)
  end

  def add_profile(name, %Profile{} = p, opts \\ [])
      when is_binary(name) and is_list(opts) do
    msg = %{:msg => :add_profile, profile: p, opts: opts}
    call_server(name, msg)
  end

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
      when is_binary(name) and is_binary(new_device) do
    msg = %{:msg => :change_device, new_device: new_device}
    call_server(name, msg)
  end

  def delete(name) when is_binary(name), do: Dutycycle.delete(name)

  # REFACTORED
  def delete(%Dutycycle{} = dc) do
    if Dutycycle.Supervisor.ping() == :pong,
      do: Dutycycle.Supervisor.eliminate_dutycycle(server_name_atom(dc)),
      else: :no_supervisor
  end

  def delete_profile(name, profile, opts \\ [])
      when is_binary(name) and
             is_binary(profile) do
    msg = %{:msg => :delete_profile, profile: profile, opts: opts}
    call_server(name, msg)
  end

  def dutycycle(server_name, opts \\ []) when is_atom(server_name) do
    msg = %{:msg => :dutycycle, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
  end

  def dutycycle_state(name, opts \\ [])
      when is_binary(name) and is_list(opts) do
    msg = %{:msg => :dutycycle_state, opts: opts}
    call_server(name, msg)
  end

  def pause(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :pause, opts: opts}
    call_server(name, msg)
  end

  def ping(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :ping, opts: opts}
    call_server(name, msg)
  end

  def profiles(name, opts \\ []) when is_binary(name) and is_list(opts) do
    msg = %{:msg => :profiles, opts: opts}
    call_server(name, msg)
  end

  def reload(name, opts \\ []) when is_binary(name) and is_list(opts) do
    msg = %{:msg => :reload, opts: opts}
    call_server(name, msg)
  end

  # REFACTORED
  def resume(name, opts \\ []) when is_binary(name) and is_list(opts) do
    # special case for resume -> request activation of the :active profile
    msg = %{:msg => :activate_profile, profile: :active, opts: opts}
    call_server(name, msg)
  end

  # REFACTORED
  def restart(name) when is_binary(name),
    do: Dutycycle.Supervisor.restart_dutycycle(name)

  # REFACTORED
  def server_name_atom(%Dutycycle{id: id}),
    do:
      String.to_atom(
        "Duty_ID" <> String.pad_leading(Integer.to_string(id), 6, "0")
      )

  def server_name_atom(nil), do: nil

  def standby(name, opts \\ []) when is_binary(name), do: pause(name, opts)

  def start_server(%Dutycycle{log: log} = d) do
    args = %{id: d.id, added: true}
    log && Logger.debug(fn -> "starting dutycycle id #{inspect(d.id)}" end)
    Supervisor.start_child(Dutycycle.Supervisor, child_spec(args))
    d
  end

  def stop(name, opts \\ [])
  def stop(name, opts) when is_binary(name), do: pause(name, opts)

  def switch_state(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :switch_state, opts: opts}
    call_server(name, msg)
  end

  def update(name, opts) when is_binary(name) and is_list(opts) do
    msg = %{:msg => :update, opts: opts}
    call_server(name, msg)
  end

  def update(_catchall), do: Logger.warn("update(dutycycle_name, opts")

  def update_profile(name, profile, opts)
      when is_binary(name) and is_binary(profile) and is_list(opts) do
    msg = %{:msg => :update_profile, profile: profile, opts: opts}

    %{profile: {rc, res}, reload: reload} = call_server(name, msg)

    # if the change was successful and it was to the active profile then
    # stop the dutycycle and then re-activate the profile to effectuate the
    # changes made
    reload && :ok === rc && Profile.active?(res) &&
      activate_profile(name, Profile.name(res))

    %{profile: {rc, res}, reload: reload}
  end

  ####
  #### GENSERVER MESSAGE HANDLERS
  ####

  def handle_call(
        %{:msg => :activate_profile, profile: profile, dutycycle: dc},
        _from,
        s
      ) do
    rc = Dutycycle.activate_profile(dc, profile)
    s = cache_dutycycle(s)

    case rc do
      {:ok, %Dutycycle{name: name, log: log} = dc, %Profile{name: profile_name},
       :run} ->
        log &&
          Logger.debug(fn ->
            "dutycycle #{inspect(name)} profile #{inspect(profile_name)} activated"
          end)

        s = cancel_timer(s) |> start_phase_timer(rc)

        {:reply, {:ok, dc}, cache_dutycycle(s)}

      {:ok, %Dutycycle{} = dc, %Profile{}, :none} ->
        {:reply, {:ok, dc}, cancel_timer(s) |> cache_dutycycle()}

      rc ->
        {:reply, {:failed, rc}, s}
    end
  end

  def handle_call(%{:msg => :add_profile, profile: p}, _from, s) do
    rc = Profile.add(s.dutycycle, p)

    s = need_reload(s, reload: true) |> reload_dutycycle()

    {:reply, rc, s}
  end

  def handle_call(
        %{:msg => :delete_profile, :profile => profile, :opts => opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = need_reload(s, opts)

    {rc, res} = Dutycycle.delete_profile(dc, profile, opts)

    {:reply, {rc, res}, cache_dutycycle(s)}
  end

  # REFACTORED!
  def handle_call(
        %{:msg => :dutycycle_state, :opts => opts},
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
        %{:msg => :change_device, new_device: new_device},
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

  def handle_call(%{:msg => :dutycycle}, _from, %{dutycycle: d} = s) do
    {:reply, d, s}
  end

  def handle_call(%{:msg => :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(
        %{:msg => :profiles, :opts => opts},
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
        %{:msg => :pause, :opts => _opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    s = cancel_timer(s)
    rc = Dutycycle.stop(dc)

    {:reply, rc, cache_dutycycle(s)}
  end

  def handle_call(%{:msg => :switch_state, :opts => _opts}, _from, s) do
    state = Switch.state(s.dutycycle.device)

    {:reply, state, s}
  end

  def handle_call(
        %{:msg => :update, :opts => opts},
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
        %{:msg => :update_profile, :profile => profile, :opts => opts},
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
  def handle_call(%{:msg => _unhandled} = msg, _from, %{dutycycle: dc} = s) do
    Logger.warn(fn ->
      "unhandled message\n" <>
        inspect(msg, pretty: true) <>
        "\n" <>
        inspect(dc, pretty: true)
    end)

    {:reply, :unhandled_msg, s}
  end

  # REFACTORED!
  # NOTE: this is nearly identical to the handle_call() for activating
  #       a profile so there is possibly an opportunity to refactor
  def handle_info(
        %{:msg => :activate_profile, profile: profile, opts: _opts},
        %{dutycycle: dc} = s
      ) do
    rc = Dutycycle.activate_profile(dc, profile)
    s = cache_dutycycle(s)

    case rc do
      {:ok, %Dutycycle{name: name, log: log}, %Profile{name: profile_name},
       :run} ->
        log &&
          Logger.debug(fn ->
            "dutycycle #{inspect(name)} profile #{inspect(profile_name)}" <>
              " server start activate successful"
          end)

        s = cancel_timer(s) |> start_phase_timer(rc)

        {:noreply, cache_dutycycle(s)}

      {:ok, %Dutycycle{}, %Profile{}, :none} ->
        {:noreply, cancel_timer(s) |> cache_dutycycle()}

      rc ->
        Logger.warn(fn ->
          "initial activate failed #{inspect(rc, pretty: true)}"
        end)

        {:noreply, s}
    end
  end

  def handle_info(
        %{:msg => :phase_end, :profile => profile, :ms => _ms},
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

  def handle_info(%{:msg => :scheduled_work}, %{server_name: server_name} = s) do
    s = reload_dutycycle(s)

    Process.send_after(server_name, %{:msg => :scheduled_work}, 750)
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

  def child_spec(%{id: id} = args) do
    {dutycycle, server_name} = server_name(id: id)
    args = Map.put(args, :dutycycle, dutycycle)

    if is_nil(dutycycle),
      do: %{},
      else: %{
        id: server_name,
        start: {Dutycycle.Server, :start_link, [args]},
        restart: :permanent,
        shutdown: 10_000
      }
  end

  # REFACTORED
  def start_link(%{id: id} = args) do
    Logger.debug(fn -> "start_link() args: #{inspect(args, pretty: true)}" end)

    opts = Application.get_env(:mcp, Dutycycle.Server, [])
    {dc, server_name} = server_name(id: id)

    GenServer.start_link(
      __MODULE__,
      %{
        server_name: server_name,
        opts: opts,
        dutycycle_id: id,
        # call Dutycycle.reload() to ensure all associations are preloaded
        dutycycle: Dutycycle.reload(dc),
        timer: nil,
        need_reload: false,
        startup_delay_ms: 15_000
      }
      |> Map.merge(args),
      name: server_name
    )
  end

  # REFACTORED
  def init(
        %{
          server_name: server_name,
          dutycycle: %Dutycycle{name: name} = dc,
          startup_delay_ms: activate_delay_ms
        } = s
      ) do
    case Dutycycle.start(dc) do
      {:ok, :stopped} ->
        nil

      {:ok, :run, profile} ->
        Process.send_after(
          server_name,
          %{:msg => :activate_profile, profile: profile, opts: []},
          activate_delay_ms
        )

        Logger.info(fn ->
          inspect(name) <>
            " profile " <>
            inspect(Profile.active(dc) |> Profile.name()) <>
            " will activate in #{inspect(activate_delay_ms)}ms"
        end)

      rc ->
        Logger.warn(fn -> "Dutycyle.start() returned:\n#{inspect(rc)}" end)
    end

    Process.flag(:trap_exit, true)
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)

    {:ok, s}
  end

  def terminate(reason, %{dutycycle: _dc}) do
    Logger.debug(fn ->
      "terminating with reason #{inspect(reason, pretty: true)}"
    end)

    # if not State.stopped?(dc), do: State.set(mode: "offline", dutycycle: dc)
  end

  ####
  #### PRIVATE FUNCTIONS
  ####

  # when called with just the state do a reload of the dutycycle
  # and cache it
  defp cache_dutycycle(%{dutycycle: dc} = s),
    do: cache_dutycycle(Dutycycle.reload(dc), s)

  # when called with a Dutycycle and the state
  # just cache the Dutycycle passed in
  defp cache_dutycycle(%Dutycycle{} = dc, %{dutycycle: _dc} = s),
    do: %{s | dutycycle: dc}

  defp call_server(name, msg) when is_binary(name) and is_map(msg) do
    {dc, server_name} = server_name(name: name)

    msg = Map.put(msg, :dutycycle, dc)
    pid = Process.whereis(server_name)

    cond do
      is_nil(dc) -> :not_found
      is_pid(pid) -> GenServer.call(server_name, msg)
      true -> :no_server
    end
  end

  # Refactor
  defp cancel_timer(%{timer: t} = s) when is_reference(t) do
    Process.cancel_timer(t)

    %{s | timer: nil}
  end

  defp cancel_timer(%{timer: nil} = s), do: s
  defp cancel_timer(%{} = s), do: s

  # if the key reload is persent in the opts then add it to the state
  # however defaults to true
  defp need_reload(%{} = s, opts) when is_list(opts),
    do: %{s | need_reload: Keyword.get(opts, :reload, true)}

  defp need_reload?(%{need_reload: reload}), do: reload

  # Refactor
  defp start_phase_timer(
         %{server_name: server} = s,
         {:ok, %Dutycycle{} = dc, %Profile{run_ms: ms} = p, :run}
       ) do
    msg = %{:msg => :phase_end, :profile => Profile.name(p), :ms => ms}
    t = Process.send_after(server, msg, ms)

    _dc = Dutycycle.persist_phase_end_timer(dc, t)

    # return an updated state
    %{s | timer: t}
  end

  # Refactor
  defp start_phase_timer(
         %{server_name: server} = s,
         {:ok, %Dutycycle{} = dc, %Profile{idle_ms: ms} = p, :idle}
       ) do
    msg = %{:msg => :phase_end, :profile => Profile.name(p), :ms => ms}
    t = Process.send_after(server, msg, ms)

    _dc = Dutycycle.persist_phase_end_timer(dc, t)

    # return an updated state
    %{s | timer: t}
  end

  # Refactor
  # handle the special case of 'none' profile
  #  a. run_ms = 0
  #  b. idle_ms = 0
  #  c. name === "none"
  defp start_phase_timer(
         %{server_name: _server} = s,
         {:ok, %Dutycycle{}, %Profile{run_ms: 0, idle_ms: 0, name: "none"},
          _mode}
       ),
       do: %{s | timer: nil}

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

  # REFACTORED
  defp server_name(opts) when is_list(opts) do
    dc = Dutycycle.get_by(opts)

    if is_nil(dc), do: {nil, nil}, else: {dc, server_name_atom(dc)}
  end
end
