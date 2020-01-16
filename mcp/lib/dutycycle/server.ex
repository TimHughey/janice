defmodule Dutycycle.Server do
  @moduledoc false

  require Logger
  use GenServer

  alias Dutycycle.Profile
  alias Dutycycle.State

  ####
  #### API
  ####

  # function header for optional "opts" parameter
  def activate_profile(name, profile_name, opts \\ [])

  # the "none" profile can never be activated, instead activate the
  # server stopped functionality
  def activate_profile(name, profile_name, opts)
      when profile_name === "none" do
    msg = %{:msg => :stop, opts: opts}
    call_server(name, msg)
  end

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
    for s <- servers, d = Dutycycle.Server.dutycycle(s), is_map(d), do: d
  end

  def all(:names) do
    servers = Dutycycle.Supervisor.known_servers()

    for s <- servers, d = Dutycycle.Server.dutycycle(s), is_map(d), do: d.name
  end

  def all(:as_maps) do
    dcs = all(:dutycycles)

    for d <- dcs, do: Dutycycle.as_map(d)
  end

  def change_device(name, new_device)
      when is_binary(name) and is_binary(new_device) do
    msg = %{:msg => :change_device, new_device: new_device}
    call_server(name, msg)
  end

  def dutycycle(server_name, opts \\ []) when is_atom(server_name) do
    msg = %{:msg => :dutycycle, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
  end

  def pause(name, opts \\ []) when is_binary(name), do: stop(name, opts)

  def pause(name, opts \\ []) when is_binary(name), do: stop(name, opts)

  def ping(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :ping, opts: opts}
    call_server(name, msg)
  end

  def profiles(name, opts \\ []) when is_binary(name) and is_list(opts) do
    msg = %{:msg => :profiles, opts: opts}
    call_server(name, msg)
  end

  def reload(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :reload, opts: opts}
    call_server(name, msg)
  end

  def resume(name, opts \\ []) when is_binary(name) do
    log = Keyword.get(opts, :log, false)

    found = ping(name)

    if found == :pong do
      profile = profiles(name, only_active: true)
      rc = activate_profile(name, profile)

      log &&
        Logger.info(fn ->
          "#{inspect(name)} resuming profile #{inspect(profile)}" <>
            " [#{inspect(rc)}]"
        end)

      rc
    else
      log &&
        Logger.warn(fn -> "#{inspect(name)} does not exist, can't resume" end)

      found
    end
  end

  def shutdown(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :shutdown, opts: opts}
    call_server(name, msg)
  end

  def standby(name, opts \\ []) when is_binary(name), do: stop(name, opts)

  def start_server(%Dutycycle{} = d) do
    args = %{id: d.id, added: true}
    Supervisor.start_child(Dutycycle.Supervisor, child_spec(args))
    d
  end

  def stop(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :stop, opts: opts}
    call_server(name, msg)
  end

  def switch_state(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :switch_state, opts: opts}
    call_server(name, msg)
  end

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

  def handle_call(%{:msg => :activate_profile} = msg, _from, s) do
    {rc, d} = handle_activate_profile(msg, s)
    profile = Profile.active(d)

    timer = Map.get(s, :timer, nil)
    if is_reference(timer), do: Process.cancel_timer(timer)

    timer =
      if rc == :ok,
        do: phase_end_timer(s, profile, profile.run_ms),
        else: nil

    s = Map.put(s, :dutycycle, d) |> Map.put(:phase_timer, timer)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :add_profile, profile: p}, _from, s) do
    rc = Profile.add(s.dutycycle, p)

    s = Map.put(s, :need_reload, true) |> reload_dutycycle()

    {:reply, rc, s}
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
        {:reply, :ok, Map.put(s, :dutycycle, dc)}

      rc ->
        Logger.warn(fn -> "unmatched change_device result" end)
        Logger.warn(fn -> "#{inspect(rc)}" end)
        {:reply, :internal_error, s}
    end
  end

  def handle_call(%{:msg => :dutycycle}, _from, %{dutycycle: d} = s) do
    {:reply, d, s}
  end

  def handle_call(%{:msg => :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(%{:msg => :profiles, :opts => opts}, _from, s) do
    profiles = Dutycycle.profiles(s.dutycycle, opts)
    {:reply, profiles, s}
  end

  def handle_call(%{:msg => :reload, :opts => opts}, _from, s) do
    log_reload = Keyword.get(opts, :log_reload, false)

    s = Map.put(s, :need_reload, true) |> Map.put_new(:log_reload, log_reload)

    {:reply, :reload_queued, s}
  end

  def handle_call(%{:msg => :stop, :opts => _opts} = msg, _from, s) do
    {rc, d} = handle_stop(msg, s)

    s = Map.put(s, :dutycycle, d) |> Map.put(:timer, nil)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :shutdown}, _from, %{dutycycle: _dc} = s) do
    {:stop, :shutdown, :ok, s}
  end

  def handle_call(%{:msg => :switch_state, :opts => _opts}, _from, s) do
    state = Switch.state(s.dutycycle.device)

    {:reply, state, s}
  end

  def handle_call(
        %{:msg => :update_profile, :profile => profile, :opts => opts},
        _from,
        %{dutycycle: dc} = s
      ) do
    # default reload to true
    reload = Keyword.get(opts, :reload, true)
    # process the actual changes to the profile
    {rc, res} = Profile.change_properties(dc, profile, opts)

    s =
      if reload do
        reload_dutycycle(s)
      else
        s
      end

    {:reply, %{profile: {rc, res}, reload: reload}, s}
  end

  # handle case when we receive a message that we don't understand
  def handle_call(%{:msg => _unhandled}, _from, s) when is_map(s) do
    {:reply, false, s}
  end

  def handle_info(
        %{:msg => :phase_end, :profile => profile, :ms => _ms},
        %{dutycycle_id: dc_id} = s
      )
      when is_binary(profile) do
    dc = Dutycycle.get_by(id: dc_id)

    active_profile = Dutycycle.profiles(dc, only_active: true)

    if active_profile == profile do
      {d, timer} = next_phase(dc, s)

      {:noreply, Map.put(s, :timer, timer) |> Map.put(:dutycycle, d)}
    else
      Logger.warn(fn ->
        "#{inspect(dc.name)}" <>
          " phase end timer for #{inspect(profile)} does not" <>
          " match active profile #{inspect(active_profile)}, ignored"
      end)

      {:noreply, Map.put(s, :dutycycle, dc)}
    end
  end

  def handle_info(%{:msg => :scheduled_work}, %{server_name: server_name} = s) do
    s = reload_dutycycle(s)

    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)
    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, %{dutycycle: dc} = s) do
    if reason == :normal do
      {{:stop, :normal}, s}
    else
      Logger.warn(fn ->
        ":EXIT #{inspect(dc.name)} message pid: #{inspect(pid)} reason: #{
          inspect(reason)
        }"
      end)

      {{:stop, reason}, s}
    end
  end

  ####
  #### GENSERVER BASE FUNCTIONS
  ####

  def child_spec(args) do
    {dutycycle, server_name} = server_name(id: args.id)
    args = Map.put(args, :dutycycle, dutycycle)

    if is_nil(dutycycle),
      do: %{},
      else: %{
        id: server_name,
        start: {Dutycycle.Server, :start_link, [args]},
        restart: :transient,
        shutdown: 10_000
      }
  end

  def start_link(args) when is_map(args) do
    Logger.debug(fn -> "start_link() args: #{inspect(args)}" end)

    opts = Application.get_env(:mcp, Dutycycle.Server, [])
    {_, name_atom} = server_name(id: args.id)

    d =
      Dutycycle.get_by(id: args.id)
      |> Repo.preload([:state, :profiles], force: true)

    s =
      args
      |> Map.put(:server_name, name_atom)
      |> Map.put(:opts, opts)
      |> Map.put(:dutycycle_id, args.id)
      |> Map.put(:dutycycle, d)

    GenServer.start_link(__MODULE__, s, name: name_atom)
  end

  def init(%{server_name: server_name} = s) do
    Process.flag(:trap_exit, true)
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)

    s = server_start(s)

    {:ok, s}
  end

  def terminate(reason, %{dutycycle: dc}) do
    Logger.debug(fn -> "terminating with reason #{inspect(reason)}" end)

    if not State.stopped?(dc), do: State.set(mode: "offline", dutycycle: dc)
  end

  ####
  #### PRIVATE FUNCTIONS
  ####

  defp call_server(name, msg) when is_binary(name) and is_map(msg) do
    {d, server_name} = server_name(name: name)

    msg = Map.put(msg, :dutycycle, d)
    pid = Process.whereis(server_name)

    cond do
      is_nil(d) -> :not_found
      is_pid(pid) -> GenServer.call(server_name, msg)
      true -> :no_server
    end
  end

  defp handle_activate_profile(%{profile: new_profile}, %{dutycycle: dc}) do
    with false <- Profile.active?(dc, new_profile),
         {1, _} <- Profile.activate(dc, new_profile),
         dc <- Dutycycle.reload(dc),
         :ok <- State.set(mode: "run", dutycycle: dc),
         {:ok, dc} <- Dutycycle.stopped(dc, false) do
      {:ok, dc}
    else
      true ->
        {:ok, dc}

      _anything ->
        {:failed, dc}
    end
  end

  defp handle_stop(_msg, %{dutycycle: dc} = s) do
    rc = State.set(mode: "stop", dutycycle: dc)

    if rc === :ok do
      timer = Map.get(s, :timer, nil)
      if is_reference(timer), do: Process.cancel_timer(timer)

      # returns tuple {rc, dutycycle} which is what the caller is expecting
      Dutycycle.stopped(dc, true)
    else
      # State.set failed, return it's rc and original dutycycle
      {rc, dc}
    end
  end

  defp next_phase(%Dutycycle{} = d, s) do
    profile = Profile.active(d)
    timer = next_phase(d, profile, s)

    {Dutycycle.get_by(id: s.dutycycle.id), timer}
  end

  defp next_phase(
         %Dutycycle{state: %State{state: "running"}} = d,
         %Profile{} = p,
         s
       ) do
    active_profile = Profile.active(d) |> Profile.name()

    # if the idle phase has actual run ms then use it
    if p.idle_ms > 0 do
      if State.set(mode: "idle", dutycycle: d) == :ok,
        do: phase_end_timer(s, active_profile, Profile.phase_ms(p, :idle)),
        else: nil
    else
      # otherwise, just continue with the run phase
      if State.set(mode: "run", dutycycle: d) == :ok,
        do: phase_end_timer(s, active_profile, Profile.phase_ms(p, :run)),
        else: nil
    end
  end

  defp next_phase(
         %Dutycycle{state: %State{state: "idling"}} = d,
         %Profile{} = p,
         s
       ) do
    active_profile = Profile.active(d) |> Profile.name()

    if p.run_ms > 0 do
      if State.set(mode: "run", dutycycle: d) == :ok,
        do: phase_end_timer(s, active_profile, Profile.phase_ms(p, :run)),
        else: nil
    else
      if State.set(mode: "idle", dutycycle: d) == :ok,
        do: phase_end_timer(s, active_profile, Profile.phase_ms(p, :idle)),
        else: nil
    end
  end

  defp next_phase(%Dutycycle{}, %Profile{}, _s), do: nil

  defp phase_end_timer(s, %Profile{} = active_profile, ms),
    do: phase_end_timer(s, Profile.name(active_profile), ms)

  defp phase_end_timer(s, active_profile, ms) when is_binary(active_profile) do
    msg = %{:msg => :phase_end, :profile => active_profile, :ms => ms}
    Process.send_after(s.server_name, msg, ms)
  end

  defp reload_dutycycle(%{dutycycle_id: id, need_reload: true} = s) do
    d = Dutycycle.get_by(id: id)
    log = Map.get(s, :log_reload, false)

    if is_nil(d) do
      Logger.warn(fn -> "failed reload of dutycycle id=#{inspect(id)}" end)
      s
    else
      log && Logger.info(fn -> "#{inspect(d.name)} reloaded" end)
      Map.merge(s, %{need_reload: false, dutycycle: d})
    end
  end

  defp reload_dutycycle(%{} = s), do: s

  defp server_name(opts) when is_list(opts) do
    d = Dutycycle.get_by(opts)

    if is_nil(d) do
      {nil, nil}
    else
      id_str = String.pad_leading(Integer.to_string(d.id), 6, "0")

      {d, String.to_atom("Duty_ID" <> id_str)}
    end
  end

  defp server_start(%{dutycycle: d, server_name: server_name} = s) do
    d = Dutycycle.ensure_profile_none_exists(d)

    cond do
      Dutycycle.stopped?(d) ->
        d.log &&
          Logger.warn(fn ->
            "Dutycycle #{inspect(d.name)} marked as stopped --" <>
              " no profile started"
          end)

      Profile.none?(d) ->
        State.set(mode: "stopped", dutycycle: d)

      true ->
        Process.send_after(
          server_name,
          %{:msg => :activate_profile, profile: Profile.active(d), opts: []},
          100
        )

        d.log &&
          Logger.info(fn ->
            "#{inspect(d.name)} queued start with profile #{
              inspect(Profile.active(d))
            }"
          end)
    end

    Map.put(s, :dutycycle, d)
  end
end
