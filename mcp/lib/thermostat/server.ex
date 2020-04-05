defmodule Thermostat.Server do
  @moduledoc false

  require Logger
  use GenServer

  use Switch

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
    servers = Thermostat.Supervisor.known_servers()

    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t.name
  end

  def all(:thermostats) do
    servers = Thermostat.Supervisor.known_servers()
    for s <- servers, t = Thermostat.Server.thermostat(s), is_map(t), do: t
  end

  def delete(name) when is_binary(name), do: Thermostat.delete(name)

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

  def restart(name) when is_binary(name),
    do: Thermostat.Supervisor.restart_thermostat(name)

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

  def update(name, opts \\ []) when is_list(opts) do
    msg = %{:msg => :update, opts: opts}
    call_server(name, msg)
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

    for x <- [
          Map.get(s, :phase_timer, nil)
        ],
        is_reference(x),
        do: Process.cancel_timer(x)

    {:reply, rc,
     Map.merge(s, %{
       phase_timer: next_check_timer(s),
       thermostat: t
     })}
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
        %{msg: :update, opts: opts},
        _from,
        %{thermostat: %Thermostat{name: name} = th} = s
      ) do
    with %Thermostat{} = x <- Thermostat.reload(th),
         {:update, {:ok, %Thermostat{} = x}} <-
           {:update, Thermostat.update(x, opts)} do
      # success, update the state with the thermostat and
      # invoke handle_continue() to apply the thermostat updates

      {:reply, {:ok, %{thermostat: x}}, %{s | thermostat: x},
       {:continue, {:apply_thermostat_updates, opts}}}
    else
      # since the update failed there are no updates to apply to the server
      # so just return the error
      {:update, error} ->
        Logger.warn([
          inspect(name),
          " update failed ",
          inspect(error, pretty: true)
        ])

        {:reply, {:failed, error}, s}

      error ->
        Logger.warn([
          inspect(name),
          " update error ",
          inspect(error, pretty: true)
        ])

        {:reply, {:error, error}, s}
    end
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

  def handle_call(catchall, _from, s) do
    Logger.warn([
      "handle_call() unhandled msg: ",
      inspect(catchall, pretty: true)
    ])

    {:reply, :unhandled_msg, s}
  end

  def handle_continue({:apply_thermostat_updates, opts}, %{thermostat: _} = s) do
    switch_check_ms = Keyword.get(opts, :switch_check_ms, false)

    if switch_check_ms do
      {:noreply, next_switch_check_timer(s)}
    else
      {:noreply, s}
    end
  end

  def handle_info(%{:msg => {:next_check, :temperature}, :ms => _ms} = msg, s) do
    s = handle_check(msg, s)
    {:noreply, s}
  end

  def handle_info(
        %{:msg => {:next_check, :switch}, :ms => _ms},
        %{thermostat: %Thermostat{}} = s
      ) do
    {:noreply, next_switch_check_timer(s)}
  end

  def handle_info(
        %{:msg => :scheduled_work},
        %{server_name: server_name} = s
      ) do
    s = reload_thermostat(s)

    Process.send_after(server_name, %{:msg => :scheduled_work}, 1000)
    {:noreply, s}
  end

  def handle_info({:EXIT, _pid, _reason} = msg, state) do
    Logger.info([
      ":EXIT msg: ",
      inspect(msg, pretty: true)
    ])

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn([
      "handle_info() unhandled msg: ",
      inspect(msg, pretty: true)
    ])

    {:noreply, state}
  end

  ####
  #### GENSERVER BASE FUNCTIONS
  ####

  def child_spec(args) do
    {thermostat, server_name} = server_name(args.id)
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

  def init(
        %{
          server_name: server_name,
          thermostat: %{switch_check_ms: switch_check_ms} = t
        } = s
      ) do
    Process.flag(:trap_exit, true)
    Process.send_after(server_name, %{:msg => :scheduled_work}, 100)
    {rc1, t} = Control.stop(t)

    switch_check_timer =
      Process.send_after(
        server_name,
        %{:msg => {:next_check, :switch}, :ms => switch_check_ms},
        switch_check_ms
      )

    s =
      Map.merge(s, %{
        switch_check_timer: switch_check_timer,
        switch_check_rc: {:before_first_check}
      })

    if rc1 == :ok do
      s = Map.put(s, :thermostat, t) |> start()

      {rc2, t} = first_check({rc1, s.thermostat})

      s =
        Map.merge(s, %{
          thermostat: t,
          phase_timer: next_check_timer(s)
        })

      if rc2 === :nil_active_profile or rc2 === :ok do
        {:ok, s}
      else
        {rc2, s}
      end
    else
      {rc1, s}
    end
  end

  def start_link(%{id: id} = args) do
    Logger.debug(["start_link() args: ", inspect(args, pretty: true)])

    opts = Application.get_env(:mcp, Thermostat.Server, [])
    {_, name_atom} = server_name(id)
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
      Logger.info([
        inspect(t.name),
        " terminate(",
        inspect(reason, pretty: true),
        ", ",
        inspect(rc, pretty: true),
        ")"
      ])

    sw_position(t.switch, position: false, lazy: true, ack: false)
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
    {t, server_name} = server_name(name)

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
        Logger.warn([
          inspect(s.thermostat.name, pretty: true),
          "unknown profile ",
          inspect(new_profile, pretty: true)
        ])

        {:unknown_profile, s.thermostat}

      new_profile === curr_profile ->
        {:no_change, s.thermostat}

      # handle the case when new and current don't match
      true ->
        actual_activate_profile(msg, s)
    end
  end

  defp handle_check(
         %{:msg => {:next_check, :temperature}, :ms => _ms},
         %{thermostat: %Thermostat{} = t} = s
       ) do
    {rc, t} = Control.temperature(t)

    timer = next_check_timer(s)

    if rc === :ok do
      Map.merge(s, %{timer: timer, thermostat: t})
    else
      Logger.warn([
        inspect(s.thermostat.name, pretty: true),
        " handle_check failed"
      ])

      Map.put(s, :timer, timer)
    end
  end

  defp handle_stop(_msg, %{thermostat: t}) do
    {rc, nt} = Thermostat.state(t, "stopped")

    sw_position(Thermostat.switch(nt), position: false)

    if rc === :ok, do: {:ok, nt}, else: {:failed, t}
  end

  defp handle_update_profile(%Thermostat{} = t, profile, opts)
       when is_map(profile) do
    Profile.update(t, profile, opts)
  end

  defp next_check_timer(%{server_name: server_name, thermostat: t}) do
    if Profile.active(t) === :none do
      nil
    else
      ms = Profile.active(t) |> Profile.check_ms()
      msg = %{:msg => {:next_check, :temperature}, :ms => ms}
      Process.send_after(server_name, msg, ms)
    end
  end

  defp next_switch_check_timer(
         %{
           server_name: server_name,
           thermostat: %Thermostat{switch_check_ms: switch_check_ms} = t,
           switch_check_timer: timer
         } = s
       ) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    msg = %{msg: {:next_check, :switch}, ms: switch_check_ms}

    %{
      s
      | switch_check_rc: Control.confirm_switch_position(t),
        switch_check_timer:
          Process.send_after(server_name, msg, switch_check_ms)
    }
  end

  # if switch_check_timer isn't in the state then add it
  defp next_switch_check_timer(%{} = s),
    do:
      Map.put_new(s, :switch_check_timer, nil)
      |> Map.put_new(:switch_check_rc, false)
      |> next_switch_check_timer()

  defp reload_thermostat(%{thermostat_id: id, need_reload: true} = s) do
    t = Thermostat.get_by(id: id)
    log = Map.get(s, :log_reload, false)

    if is_nil(t) do
      Logger.warn(["id=", inspect(id, pretty: true), " reload failed"])
      s
    else
      log && Logger.info([inspect(t.name, pretty: true), " reloaded"])
      Map.merge(s, %{need_reload: false, thermostat: t})
    end
  end

  # do nothing if need_reload is false or doesn't exist
  defp reload_thermostat(%{} = s), do: s

  def server_name(x) when is_binary(x) or is_integer(x) do
    th = Thermostat.find(x)

    if is_nil(th), do: {nil, nil}, else: {th, server_name_atom(th)}
  end

  defp server_name_atom(%{id: _} = th),
    do: Thermostat.Supervisor.server_name_atom(th)

  defp server_name_atom(_), do: :no_server

  defp start(%{thermostat: %Thermostat{}} = s) do
    sw_position(Thermostat.switch(s.thermostat),
      position: false,
      lazy: true
    )

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
