defmodule Thermostat.Server do
  @moduledoc """

  """

  require Logger
  use GenServer
  use Timex

  alias Thermostat.Profile
  alias Thermostat.Control

  ####
  #### API
  ####

  def activate_profile(name, profile, opts \\ [])
      when is_binary(name) and is_binary(profile) and is_list(opts) do
    msg = %{:msg => :activate_profile, profile: profile, opts: opts}
    call_server(name, msg)
  end

  def all(:names) do
    servers = Dutycycle.Supervisor.known_servers("Thermo_ID")

    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t.name
  end

  def all(:thermostats) do
    servers = Dutycycle.Supervisor.known_servers("Thermo_ID")
    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t
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

  def owner(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :owner, opts: opts}
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

  def start_server(%Thermostat{} = t) do
    args = %{id: t.id, added: true}
    Supervisor.start_child(Dutycycle.Supervisor, child_spec(args))
    t
  end

  def state(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :state, opts: opts}
    call_server(name, msg)
  end

  def release_ownership(name, opts \\ []) when is_binary(name) do
    msg = %{:msg => :release_ownership, opts: opts}
    call_server(name, msg)
  end

  def take_ownership(name, owner, opts \\ []) when is_binary(name) do
    msg = %{:msg => :take_ownership, owner: owner, opts: opts}
    call_server(name, msg)
  end

  def thermostat(server_name, opts \\ []) when is_atom(server_name) do
    msg = %{:msg => :thermostat, opts: opts}

    pid = Process.whereis(server_name)

    if is_pid(pid), do: GenServer.call(server_name, msg), else: :no_server
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

  def handle_call(%{:msg => :enable} = msg, _from, s) do
    msg = Map.put(msg, :set, true)
    {rc, t} = handle_enable(msg, s)

    s = Map.put(s, :thermostat, t)

    {:reply, rc, s}
  end

  def handle_call(%{:msg => :enabled?}, _from, s) do
    {:reply, s.thermostat.enable, s}
  end

  def handle_call(%{:msg => :owner, :opts => opts}, _from, s) do
    owner = Thermostat.owner(s.thermostat, opts)
    {:reply, owner, s}
  end

  def handle_call(%{:msg => :ping}, _from, s) do
    {:reply, :pong, s}
  end

  def handle_call(%{:msg => :profiles, :opts => opts}, _from, s) do
    profiles = Thermostat.profiles(s.thermostat, opts)

    {:reply, profiles, s}
  end

  def handle_call(%{:msg => :release_ownership, :opts => opts}, _from, s) do
    {res, t} = Thermostat.release_ownership(s.thermostat, opts)
    s = Map.put(s, :thermostat, t)

    {:reply, res, s}
  end

  def handle_call(%{:msg => :shutdown}, _from, s) do
    {:stop, :shutdown, :ok, s}
  end

  def handle_call(%{:msg => :state, :opts => _opts}, _from, s) do
    {:reply, s.thermostat.state, s}
  end

  def handle_call(%{:msg => :take_ownership, :owner => owner, :opts => opts}, _from, s) do
    {res, t} = Thermostat.take_ownership(s.thermostat, owner, opts)
    s = Map.put(s, :thermostat, t)

    {:reply, res, s}
  end

  def handle_call(%{:msg => :thermostat, :opts => _opts}, _from, s) do
    {:reply, s.thermostat, s}
  end

  def handle_info(%{:msg => :next_check, :ms => _ms} = msg, s) do
    s = handle_check(msg, s)
    {:noreply, s}
  end

  def handle_info(%{:msg => :scheduled_work}, %{server_name: server_name} = s) do
    Process.send_after(server_name, %{:msg => :scheduled_work}, 300)
    {:noreply, s}
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
        restart: :transient
      }
  end

  def init(%{server_name: server_name} = s) do
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)
    {rc, t} = Control.stop(s.thermostat)

    s = Map.put(s, :thermostat, t) |> start()

    {rc, t} = first_check({rc, s.thermostat})

    s = Map.put(s, :thermostat, t)

    timer = next_check_timer(s)

    s = Map.put(s, :timer, timer)

    {:ok, s}
  end

  def start_link(args) when is_map(args) do
    Logger.debug(fn -> "start_link() args: #{inspect(args)}" end)

    opts = Application.get_env(:mcp, Thermostat.Server, [])
    {_, name_atom} = server_name(id: args.id)
    t = Thermostat.get_by(id: args.id)

    s =
      args
      |> Map.put(:server_name, name_atom)
      |> Map.put(:opts, opts)
      |> Map.put(:thermostat_id, args.id)
      |> Map.put(:thermostat, t)

    GenServer.start_link(__MODULE__, s, name: name_atom)
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

  defp enable_if_requested(%{opts: opts}, s) do
    enable = opts[:enable] || false

    if enable do
      {rc, t} = Thermostat.enable(s.theromstat, true)
      e = if rc == :ok, do: Thermostat.enabled?(t), else: false
      {t, e}
    else
      {s.thermostat, Thermostat.enabled?(s.thermostat)}
    end
  end

  defp first_check({:ok, %Thermostat{} = t}) do
    Control.temperature(t)
  end

  defp handle_activate_profile(%{opts: opts} = msg, s) do
    new_profile = opts[:profile] || nil
    enable = opts[:enable] || false
    known_profile = Profile.known?(s.thermostat, new_profile)

    {t, enabled} = enable_if_requested(msg, s)
    s = Map.put(s, :thermostat, t)
    curr_profile = Profile.active(t)

    cond do
      not known_profile ->
        Logger.warn(fn ->
          "unknown profile [#{new_profile}] for thermostat [#{s.thermostat.name}]"
        end)

        {:unknown_profile, s.thermostat}

      not enabled ->
        {:disabled, s.thermostat}

      # handle the case when enable requested
      enable ->
        actual_activate_profile(msg, s)

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

  defp handle_enable(msg, s) do
    {rc, t} = Thermostat.enable(s.thermostat, msg.set)

    if rc === :ok, do: {:ok, t}, else: {:failed, s.thermostat}
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
  defp start(%{thermostat: %Thermostat{owned_by: owner}} = s) when is_nil(owner) do
    SwitchState.state(Thermostat.switch(s.thermostat), position: false)

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
