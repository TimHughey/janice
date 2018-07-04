defmodule Dutycycle.Server do
  @moduledoc false

  require Logger
  use GenServer
  use Timex

  alias Dutycycle.Profile
  alias Dutycycle.State

  ####
  #### API
  ####

  def activate_profile(name, profile_name, opts \\ [])
      when is_binary(name) and is_binary(profile_name) do
    msg = %{:msg => :activate_profile, profile: profile_name, opts: opts}
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

  def disable(name, opts \\ [])
      when is_binary(name) do
    msg = %{:msg => :disable, opts: opts}
    call_server(name, msg)
  end

  def dutycycle(server_name, opts \\ []) when is_atom(server_name) do
    msg = %{:msg => :dutycycle, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
  end

  def enable(name, opts \\ [])
      when is_binary(name) do
    msg = %{:msg => :enable, opts: opts}
    call_server(name, msg)
  end

  def enabled?(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :enabled?, opts: opts}
    call_server(name, msg)
  end

  def ping(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :ping, opts: opts}
    call_server(name, msg)
  end

  def profiles(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :profiles, opts: opts}
    call_server(name, msg)
  end

  def shutdown(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :shutdown, opts: opts}
    call_server(name, msg)
  end

  def standalone(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :standalone, opts: opts}
    call_server(name, msg)
  end

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

  ####
  #### GENSERVER MESSAGE HANDLERS
  ####

  def handle_call(%{:msg => :activate_profile} = msg, _from, s) do
    {rc, d} = handle_activate_profile(msg, s)
    profile = Profile.active(d)

    timer = Map.get(s, :timer, nil)
    if is_reference(timer), do: Process.cancel_timer(timer)

    timer =
      if rc == :ok and profile != :none,
        do: phase_end_timer(s, profile.run_ms),
        else: nil

    s = Map.put(s, :dutycycle, d) |> Map.put(:phase_timer, timer)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :disable} = msg, _from, s) do
    msg = Map.put(msg, :set, false)
    {rc, d} = handle_enable(msg, s)

    s = Map.put(s, :dutycycle, d)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :dutycycle}, _from, %{dutycycle: d} = s) do
    {:reply, d, s}
  end

  def handle_call(%{:msg => :enable} = msg, _from, s) do
    msg = Map.put(msg, :set, true)
    {rc, d} = handle_enable(msg, s)

    s = Map.put(s, :dutycycle, d)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :enabled?}, _from, s) do
    {:reply, s.dutycycle.enable, s}
  end

  def handle_call(%{:msg => :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(%{:msg => :profiles, :opts => opts}, _from, s) do
    profiles = Dutycycle.profiles(s.dutycycle, opts)
    {:reply, profiles, s}
  end

  def handle_call(%{:msg => :standalone, :opts => opts}, _from, s) do
    val = Keyword.get(opts, :set, true)

    {rc, d} = Dutycycle.standalone(s.dutycycle, val)

    s = Map.put(s, :dutycycle, d) |> start_standalone()

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :stop, :opts => _opts} = msg, _from, s) do
    {rc, d} = handle_stop(msg, s)

    s = Map.put(s, :dutycycle, d)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :shutdown}, _from, s) do
    {:stop, :shutdown, :ok, s}
  end

  def handle_call(%{:msg => :switch_state, :opts => _opts}, _from, s) do
    state = SwitchState.state(s.dutycycle.device)

    {:reply, state, s}
  end

  # handle case when we receive a message that we don't understand
  def handle_call(%{:msg => _unhandled}, _from, s) when is_map(s) do
    {:reply, false, s}
  end

  def handle_info(%{:msg => :phase_end, :ms => _ms}, %{dutycycle: dc} = s) do
    {d, timer} = next_phase(dc, s)

    s = Map.put(s, :timer, timer) |> Map.put(:dutycycle, d)

    {:noreply, s}
  end

  def handle_info(%{:msg => :scheduled_work}, %{server_name: server_name} = s) do
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)
    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug(fn -> ":EXIT message " <> "pid: #{inspect(pid)} reason: #{inspect(reason)}" end)

    {:noreply, state}
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
    d = Dutycycle.get_by(id: args.id)

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

    s = start_standalone(s)

    {:ok, s}
  end

  def terminate(_reason, s) do
    if s.dutycycle.standalone, do: State.set(mode: "stop", dutycycle: s.dutycycle)
  end

  ####
  #### PRIVATE FUNCTIONS
  ####

  defp actual_activate_profile(msg, s) do
    new = msg.profile
    rc = Profile.activate(s.dutycycle, new)

    if is_tuple(rc) and elem(rc, 0) == 1 do
      d = Dutycycle.get_by(id: s.dutycycle_id) |> Repo.preload([:profiles])
      rc = State.set(mode: "run", dutycycle: d)
      d = Dutycycle.get_by(id: s.dutycycle_id) |> Repo.preload([:profiles, :state])

      {rc, d}
    else
      {:failed, s.dutycycle}
    end
  end

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

  defp handle_activate_profile(msg, s) do
    enable = Keyword.get(msg.opts, :enable, false)

    {d, enabled} =
      if enable do
        {rc, d} = Dutycycle.enable(s.dutycycle, true)
        e = if rc == :ok, do: Map.get(d, :enable), else: false
        {d, e}
      else
        {s.dutycycle, Map.get(s.dutycycle, :enable)}
      end

    new = msg.profile
    curr = Profile.active(s.dutycycle)

    cond do
      not enabled ->
        {:disabled, s.dutycycle}

      # handle the case when enable requested
      enable ->
        s = Map.put(s, :dutycycle, d)
        actual_activate_profile(msg, s)

      new === curr ->
        {:no_change, s.dutycyle}

      # handle the case when new and current don't match
      true ->
        actual_activate_profile(msg, s)
    end
  end

  defp handle_enable(msg, s) do
    {rc, d} = Dutycycle.enable(s.dutycycle, msg.set)

    if rc === :ok, do: {:ok, d}, else: {:failed, s.dutycycle}
  end

  defp handle_stop(_msg, s) do
    rc = State.set(mode: "stop", dutycycle: s.dutycycle)
    d = Dutycycle.get_by(id: s.dutycycle_id) |> Repo.preload([:profiles, :state])
    {rc, d}
  end

  defp next_phase(%Dutycycle{} = d, s) do
    profile = Profile.active(d)
    timer = next_phase(d, profile, s)

    {Dutycycle.get_by(id: s.dutycycle.id), timer}
  end

  defp next_phase(%Dutycycle{state: %State{state: "running"}} = d, %Profile{} = p, s) do
    # if the idle phase has actual run ms then use it
    if p.idle_ms > 0 do
      if State.set(mode: "idle", dutycycle: d) == :ok,
        do: phase_end_timer(s, Profile.phase_ms(p, :idle)),
        else: nil
    else
      # otherwise, just continue with the run phase
      if State.set(mode: "run", dutycycle: d) == :ok,
        do: phase_end_timer(s, Profile.phase_ms(p, :run)),
        else: nil
    end
  end

  defp next_phase(%Dutycycle{state: %State{state: "idling"}} = d, %Profile{} = p, s) do
    if p.run_ms > 0 do
      if State.set(mode: "run", dutycycle: d) == :ok,
        do: phase_end_timer(s, Profile.phase_ms(p, :run)),
        else: nil
    else
      if State.set(mode: "idle", dutycycle: d) == :ok,
        do: phase_end_timer(s, Profile.phase_ms(p, :idle)),
        else: nil
    end
  end

  defp next_phase(%Dutycycle{}, %Profile{}, _s), do: nil

  defp phase_end_timer(s, ms) do
    msg = %{:msg => :phase_end, :ms => ms}
    Process.send_after(s.server_name, msg, ms)
  end

  defp server_name(opts) when is_list(opts) do
    d = Dutycycle.get_by(opts)

    if is_nil(d) do
      {nil, nil}
    else
      id_str = String.pad_leading(Integer.to_string(d.id), 6, "0")

      {d, String.to_atom("Duty_ID" <> id_str)}
    end
  end

  defp start_standalone(%{dutycycle: %Dutycycle{standalone: false}} = s), do: s
  defp start_standalone(%{dutycycle: %Dutycycle{standalone: true, enable: false}} = s), do: s

  defp start_standalone(%{dutycycle: %Dutycycle{standalone: true, enable: true} = d} = s) do
    p = Profile.active(d)

    {d, timer} =
      if p == :none do
        {d, nil}
      else
        State.set(mode: "run", dutycycle: d)
        d = Dutycycle.get_by(id: s.dutycycle_id) |> Repo.preload([:profiles, :state])
        timer = phase_end_timer(s, Profile.phase_ms(p, :run))
        {d, timer}
      end

    Map.put(s, :timer, timer) |> Map.put(:dutycycle, d)
  end
end
