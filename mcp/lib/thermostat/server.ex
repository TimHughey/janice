defmodule Thermostat.Server do
  @moduledoc false

  require Logger
  use GenServer

  alias Thermostat.Control
  alias Thermostat.Profile

  ####
  #### API
  ####

  def activate_profile(name, profile, opts \\ [])
      when is_binary(name) and is_binary(profile) and is_list(opts) do
    msg = %{:msg => :activate_profile, profile: profile, opts: opts}
    call_server(name, msg)
  end

  def add_profile(name, %Profile{} = p, opts \\ [])
      when is_binary(name) and is_list(opts) do
    msg = %{:msg => :add_profile, profile: p, opts: opts}
    call_server(name, msg)
  end

  def all(:names) do
    servers = Thermostat.Supervisor.known_servers("Thermo_ID")

    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t.name
  end

  def all(:thermostats) do
    servers = Thermostat.Supervisor.known_servers("Thermo_ID")
    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t
  end

  def delete(name) when is_binary(name), do: Thermostat.delete(name)

  # REFACTORED
  def delete(%Thermostat{} = th) do
    if Thermostat.Supervisor.ping() == :pong,
      do: Thermostat.Supervisor.eliminate_child(server_name_atom(th)),
      else: :no_supervisor
  end

  def ping(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :ping, opts: opts}
    call_server(name, msg)
  end

  def profiles(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :profiles, opts: opts}
    call_server(name, msg)
  end

  def reload(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :reload, opts: opts}
    call_server(name, msg)
  end

  # REFACTORED
  def restart(name) when is_binary(name),
    do: Thermostat.Supervisor.restart_thermostat(name)

  # REFACTORED
  def server_name_atom(%Thermostat{id: id}),
    do:
      String.to_atom(
        "Thermo_ID" <> String.pad_leading(Integer.to_string(id), 6, "0")
      )

  def server_name_atom(nil), do: nil

  def standby(name, opts \\ [])
      when is_binary(name) and is_list(opts) do
    msg = %{:msg => :activate_profile, profile: "standby", opts: opts}
    call_server(name, msg)
  end

  def start_server(%Thermostat{} = t) do
    args = %{id: t.id, added: true}
    Supervisor.start_child(Thermostat.Supervisor, child_spec(args))
    t
  end

  def state(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :state, opts: opts}
    call_server(name, msg)
  end

  def stop(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :stop, opts: opts}
    call_server(name, msg)
  end

  def thermostat(server_name, opts \\ []) when is_atom(server_name) do
    msg = %{:msg => :thermostat, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
  end

  def update_profile(name, %{name: profile} = map, opts \\ [])
      when is_binary(profile) do
    msg = %{:msg => :update_profile, :profile => map, opts: opts}
    call_server(name, msg)
  end

  ####
  #### GENSERVER MESSAGE HANDLERS
  ####

  def handle_call(%{:msg => :activate_profile} = msg, _from, s) do
    {rc, t} = handle_activate_profile(msg, s)
    active = Profile.active(t)

    timer = Map.get(s, :timer, nil)
    if is_reference(timer), do: Process.cancel_timer(timer)

    timer =
      if rc == :ok and active != :none,
        do: next_check_timer(s),
        else: nil

    s = Map.put(s, :thermostat, t) |> Map.put(:phase_timer, timer)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :add_profile, profile: p}, _from, s) do
    rc = Profile.add(s.thermostat, p)

    s = Map.put(s, :need_reload, true) |> reload_thermostat()

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(
        %{:msg => :profiles, :opts => opts},
        _from,
        %{thermostat: th} = s
      ) do
    profiles = Thermostat.profiles(th, opts)

    {:reply, profiles, s}
  end

  def handle_call(%{:msg => :reload, :opts => _opts}, _from, s) do
    s = Map.put(s, :need_reload, true)

    {:reply, :reload_queued, s}
  end

  def handle_call(%{:msg => :state, :opts => _opts}, _from, s) do
    {:reply, s.thermostat.state, s}
  end

  def handle_call(%{:msg => :stop, :opts => _opts} = msg, _from, s) do
    {_res, t} = handle_stop(msg, s)

    s = Map.merge(s, %{thermostat: t})

    {:reply, :ok, s}
  end

  def handle_call(%{:msg => :thermostat, :opts => _opts}, _from, s) do
    {:reply, s.thermostat, s}
  end

  def handle_call(
        %{:msg => :update_profile, :profile => profile, :opts => opts},
        _from,
        s
      ) do
    reload = Keyword.get(opts, :reload, false)
    log_reload = Keyword.get(opts, :log_reload, false)
    {res, t} = handle_update_profile(s.thermostat, profile, opts)

    s =
      Map.merge(s, %{thermostat: t, need_reload: reload, log_reload: log_reload})
      |> reload_thermostat()

    {:reply, res, s}
  end

  def handle_info(%{:msg => :next_check, :ms => _ms} = msg, s) do
    s = handle_check(msg, s)
    {:noreply, s}
  end

  def handle_info(
        %{:msg => :scheduled_work},
        %{server_name: server_name} = s
      ) do
    s = reload_thermostat(s)

    Process.send_after(server_name, %{:msg => :scheduled_work}, 1000)
    {:noreply, s}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug(fn ->
      ":EXIT message " <> "pid: #{inspect(pid)} reason: #{inspect(reason)}"
    end)

    {:noreply, state}
  end

  ####
  #### GENSERVER BASE FUNCTIONS
  ####

  def child_spec(args) do
    {thermostat, server_name} = server_name(id: args.id)
    args = Map.put(args, :thermostat, thermostat)

    if is_nil(thermostat),
      do: %{},
      else: %{
        id: server_name,
        start: {Thermostat.Server, :start_link, [args]},
        restart: :permanent,
        shutdown: 10_000
      }
  end

  def init(%{server_name: server_name} = s) do
    Process.flag(:trap_exit, true)
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)
    {rc1, t} = Control.stop(s.thermostat)

    if rc1 == :ok do
      s = Map.put(s, :thermostat, t) |> start()

      {rc2, t} = first_check({rc1, s.thermostat})

      s = Map.put(s, :thermostat, t)

      timer = next_check_timer(s)

      s = Map.put(s, :timer, timer)

      if rc2 === :nil_active_profile or rc2 === :ok do
        Logger.debug("init() returning #{inspect({:ok, s}, pretty: true)}")
        {:ok, s}
      else
        Logger.debug("init() returning #{inspect({rc2, s}, pretty: true)}")
        {rc2, s}
      end
    else
      Logger.debug("init() returning #{inspect({rc1, s}, pretty: true)}")
      {rc1, s}
    end
  end

  def start_link(%{id: id} = args) do
    Logger.debug(fn -> "start_link() args: #{inspect(args, pretty: true)}" end)

    opts = Application.get_env(:mcp, Thermostat.Server, [])
    {_, name_atom} = server_name(id: id)
    t = Thermostat.get_by(id: id)

    s =
      %{server_name: name_atom, opts: opts, thermostat_id: id, thermostat: t}
      |> Map.merge(args)

    GenServer.start_link(__MODULE__, s, name: name_atom)
  end

  def terminate(reason, s) do
    {rc, t} = Thermostat.state(s.thermostat, "stopped")
    log = Map.get(s, :log_terminate, false)

    log &&
      Logger.info(fn ->
        "#{inspect(t.name)} terminate(#{inspect(reason)}) #{inspect(rc)}"
      end)

    Switch.position(t.switch, position: false, lazy: true, ack: false)
    :ok
  end

  ####
  #### PRIVATE FUNCTIONS
  ####

  defp actual_activate_profile(%{profile: new}, s) do
    {rc, t} = Thermostat.activate_profile(s.thermostat, new)

    if rc == :ok, do: {rc, t}, else: {rc, s.thermostat}
  end

  defp call_server(name, msg) when is_binary(name) and is_map(msg) do
    {t, server_name} = server_name(name: name)

    msg = Map.put(msg, :thermostat, t)
    pid = Process.whereis(server_name)

    cond do
      is_nil(t) -> :not_found
      is_pid(pid) -> GenServer.call(server_name, msg)
      true -> :no_server
    end
  end

  defp first_check({:ok, %Thermostat{} = t}) do
    Control.temperature(t)
  end

  defp handle_activate_profile(
         %{profile: new_profile, opts: _opts} = msg,
         %{thermostat: t} = s
       ) do
    known_profile = Profile.known?(s.thermostat, new_profile)

    s = Map.put(s, :thermostat, t)
    curr_profile = Profile.active(t)

    cond do
      not known_profile ->
        Logger.warn(fn ->
          "unknown profile [#{new_profile}] for thermostat [#{s.thermostat.name}]"
        end)

        {:unknown_profile, s.thermostat}

      new_profile === curr_profile ->
        {:no_change, s.thermostat}

      # handle the case when new and current don't match
      true ->
        actual_activate_profile(msg, s)
    end
  end

  defp handle_check(%{:msg => :next_check, :ms => _ms}, s) do
    {rc, t} = Control.temperature(s.thermostat)

    timer = next_check_timer(s)

    if rc === :ok do
      Map.merge(s, %{timer: timer, thermostat: t})
    else
      Logger.warn(fn -> "[#{s.thermostat.name}] handle_check failed" end)
      Map.put(s, :timer, timer)
    end
  end

  defp handle_stop(_msg, %{thermostat: t}) do
    {rc, nt} = Thermostat.state(t, "stopped")

    Switch.position(Thermostat.switch(nt), position: false)

    if rc === :ok, do: {:ok, nt}, else: {:failed, t}
  end

  defp handle_update_profile(%Thermostat{} = t, profile, opts)
       when is_map(profile) do
    Profile.update(t, profile, opts)
  end

  defp next_check_timer(s) when is_map(s) do
    profile = Profile.active(s.thermostat)

    if profile === :none do
      nil
    else
      ms = Profile.check_ms(profile)
      msg = %{:msg => :next_check, :ms => ms}
      Process.send_after(s.server_name, msg, ms)
    end
  end

  defp reload_thermostat(%{thermostat_id: id, need_reload: true} = s) do
    t = Thermostat.get_by(id: id)
    log = Map.get(s, :log_reload, false)

    if is_nil(t) do
      Logger.warn(fn -> "failed reload of thermostat id=#{id}" end)
      s
    else
      log && Logger.info(fn -> "#{inspect(t.name)} reloaded" end)
      Map.merge(s, %{need_reload: false, thermostat: t})
    end
  end

  # do nothing if need_reload is false or doesn't exist
  defp reload_thermostat(%{} = s), do: s

  defp server_name(opts) when is_list(opts) do
    d = Thermostat.get_by(opts)

    if is_nil(d) do
      {nil, nil}
    else
      id_str = String.pad_leading(Integer.to_string(d.id), 6, "0")

      {d, String.to_atom("Thermo_ID" <> id_str)}
    end
  end

  # start a __standalone__ thermostat (owner is nil)
  defp start(%{thermostat: %Thermostat{}} = s) do
    Switch.position(Thermostat.switch(s.thermostat), position: false, lazy: true)

    timer = next_check_timer(s)
    {rc, t} = Thermostat.state(s.thermostat, "started")

    if rc === :ok,
      do: Map.put(s, :timer, timer) |> Map.put(:thermostat, t),
      else: s
  end

  defp start(s) when is_map(s) do
    {rc, t} = Thermostat.state(s.thermostat, "started")

    if rc === :ok,
      do: Map.put(s, :thermostat, t),
      else: s
  end
end
