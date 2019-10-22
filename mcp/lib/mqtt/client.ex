defmodule Mqtt.Client do
  @moduledoc false

  require Logger
  use GenServer

  alias Tortoise.Connection

  import Application, only: [get_env: 2, get_env: 3]
  alias Fact.RunMetric
  alias Mqtt.Timesync

  #  def child_spec(opts) do
  #
  #    %{
  #      id: Mqtt.Client,
  #      start: {Mqtt.Client, :start_link, [opts]},
  #      restart: :permanent,
  #      shutdown: 5000,
  #      type: :supervisor
  #    }
  #  end

  def start_link(s) when is_map(s) do
    GenServer.start_link(__MODULE__, s, name: __MODULE__)
  end

  ## Callbacks

  def connected do
    GenServer.cast(__MODULE__, {:connected})
  end

  def disconnected do
    GenServer.cast(__MODULE__, {:disconnected})
  end

  def inbound_msg(topic, payload) do
    GenServer.cast(__MODULE__, {:inbound_msg, topic, payload})
  end

  def init(s) when is_map(s) do
    Logger.info(fn -> "init()" end)

    s = Map.put_new(s, :runtime_metrics, false)

    if Map.get(s, :autostart, false) do
      # prepare the opts that will be passed to Tortoise and start it

      opts = config(:tort_opts) ++ [handler: {Mqtt.Handler, []}]
      {:ok, mqtt_pid} = Connection.start_link(opts)

      # populate the state and construct init() return
      new_state = %{
        mqtt_pid: mqtt_pid,
        client_id: Keyword.get(opts, :client_id)
      }

      s = Map.merge(s, new_state)

      Logger.info(fn -> "tortoise pid(#{inspect(mqtt_pid)})" end)

      {:ok, s}
    else
      # when we don't autostart the mqtt pid will be nil
      s = Map.put_new(s, :mqtt_pid, nil) |> Map.put_new(:client_id, nil)

      {:ok, s}
    end

    # init() return is calculated above in if block
    # at the conclusion of init() we have a running InboundMessage GenServer and
    # potentially a connection to MQTT
  end

  def report_subscribe do
    feed = get_env(:mcp, :feeds, []) |> Keyword.get(:rpt, nil)
    subscribe(feed)
  end

  def runtime_metrics, do: GenServer.call(__MODULE__, {:runtime_metrics})

  def runtime_metrics(flag) when is_boolean(flag) or flag == :toggle do
    GenServer.call(__MODULE__, {:runtime_metrics, flag})
  end

  def send_timesync do
    GenServer.call(__MODULE__, {:timesync_msg})
  end

  def subscribe(feed) when is_nil(feed) do
    Logger.warn(fn -> "can't subscribe to nil feed" end)
    Logger.warn(fn -> "hint: check :feeds are defined in the configuration" end)
    :ok
  end

  def subscribe(feed) when is_tuple(feed) do
    GenServer.call(__MODULE__, {:subscribe, feed})
  end

  def subscribe(feed) do
    Logger.warn(fn ->
      "subscribe feed doesn't make sense, got #{inspect(feed)}"
    end)

    Logger.warn(fn -> "hint: subscribe feed should be a tuple" end)
    :ok
  end

  def publish(message) when is_binary(message) do
    {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, {nil, nil})
    payload = message
    pub_opts = [qos]

    opts = [feed: feed, message: payload, pub_opts: pub_opts]
    publish(opts)
  end

  def publish(opts) when is_list(opts) do
    feed = Keyword.get(opts, :feed, nil)
    payload = Keyword.get(opts, :message, nil)
    pub_opts = Keyword.get(opts, :pub_opts, [])

    MessageSave.save(:out, payload)

    if is_nil(feed) or is_nil(payload) do
      Logger.warn(fn ->
        "can't publish: feed=#{inspect(feed)} payload=#{inspect(payload)}"
      end)

      Logger.warn(fn ->
        "hint: check :feeds are defined in the configuration"
      end)

      :ok
    else
      Logger.debug(fn -> "outbound: #{payload}" end)

      GenServer.call(__MODULE__, {:publish, feed, payload, pub_opts})
    end
  end

  def publish_ota(raw) when is_binary(raw) do
    {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:ota, {nil, nil})
    payload = raw
    pub_opts = [qos]

    opts = [feed: feed, message: payload, pub_opts: pub_opts]
    publish(opts)
  end

  def publish_switch_cmd(message) do
    {elapsed_us, _res} =
      :timer.tc(fn ->
        {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, {nil, nil})
        payload = message
        pub_opts = [qos]

        opts = [feed: feed, message: payload, pub_opts: pub_opts]
        publish(opts)
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "publish_switch_cmd_us",
      device: "none",
      val: elapsed_us
    )
  end

  def handle_call(
        {:publish, feed, payload, pub_opts},
        _from,
        %{autostart: true} = s
      )
      when is_binary(feed) and is_binary(payload) and is_list(pub_opts) do
    {elapsed_us, res} =
      :timer.tc(fn ->
        Tortoise.publish(s.client_id, feed, payload, pub_opts)
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "mqtt_pub_msg_us",
      device: "none",
      val: elapsed_us,
      record: s.runtime_metrics
    )

    {:reply, res, s}
  end

  def handle_call(
        {:publish, feed, payload, pub_opts},
        _from,
        %{autostart: false} = s
      )
      when is_binary(feed) and is_binary(payload) and is_list(pub_opts) do
    Logger.debug(fn -> "not started, dropping #{inspect(payload)}" end)
    {:reply, :not_started, s}
  end

  def handle_call({:subscribe, feed}, _from, s)
      when is_tuple(feed) do
    {:ok, ref} = Connection.subscribe(s.client_id, feed)

    Logger.info(fn -> "subscribing to #{inspect(feed)} ref: #{inspect(ref)}" end)

    {:reply, ref, s}
  end

  def handle_call({:runtime_metrics}, _from, %{runtime_metrics: flag} = s),
    do: {:reply, flag, s}

  def handle_call({:runtime_metrics, flag}, _from, %{runtime_metrics: was} = s)
      when is_boolean(flag) or flag == :toggle do
    new_flag =
      if flag == :toggle do
        not s.runtime_metrics
      else
        flag
      end

    s = Map.put(s, :runtime_metrics, new_flag)

    {:reply, %{was: was, is: s.runtime_metrics}, s}
  end

  def handle_call({:timesync_msg}, _from, s) do
    {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, {nil, nil})

    if is_nil(feed) or is_nil(qos) do
      Logger.warn(fn -> "can't send timesync, feed configuration missing" end)
      {:reply, {:failed}, s}
    else
      payload = Timesync.new_cmd() |> Timesync.json()
      pub_opts = [qos]

      res = Tortoise.publish(s.client_id, feed, payload, pub_opts)
      {:reply, {res}, s}
    end
  end

  def handle_call(unhandled_msg, _from, s) do
    log_unhandled("call", unhandled_msg)
    {:reply, :ok, s}
  end

  def handle_cast({:connected}, s) do
    s = Map.put(s, :connected, true)
    Logger.info(fn -> "mqtt endpoint connected" end)

    # subscribe to the report feed
    feed = get_env(:mcp, :feeds, []) |> Keyword.get(:rpt, nil)
    res = Connection.subscribe(s.client_id, [feed])

    s = Map.put(s, :rpt_feed_subscribed, res)

    s = start_timesync_task(s)

    {:noreply, s}
  end

  def handle_cast({:disconnected}, s) do
    Logger.warn(fn -> "mqtt endpoint disconnected" end)
    s = Map.put(s, :connected, false)
    {:noreply, s}
  end

  def handle_cast({:inbound_msg, _topic, message}, s) do
    {elapsed_us, _res} =
      :timer.tc(fn ->
        MessageSave.save(:in, message)

        Mqtt.InboundMessage.process(message, runtime_metrics: s.runtime_metrics)
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "mqtt_recv_msg_us",
      device: "none",
      val: elapsed_us,
      record: s.runtime_metrics
    )

    {:noreply, s}
  end

  def handle_cast(unhandled_msg, s) do
    log_unhandled("cast", unhandled_msg)
    {:noreply, s}
  end

  def handle_info({{Tortoise, _client_id}, ref, res}, s) do
    log = Map.get(s, :log_subscriptions, false)

    log &&
      Logger.warn(fn -> "subscription ref: #{inspect(ref)} #{inspect(res)}" end)

    {:noreply, s}
  end

  def handle_info(
        {ref, result} = msg,
        %{timesync: %{task: %{ref: timesync_ref}}} = s
      )
      when is_reference(ref) and ref == timesync_ref do
    Logger.debug(fn -> "handle_info(#{inspect(msg)}, #{inspect(s)})" end)
    s = Map.put(s, :timesync, Map.put(s.timesync, :result, result))

    {:noreply, s}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason} = msg,
        %{timesync: %{task: %{ref: timesync_ref}}} = s
      )
      when is_reference(ref) and is_pid(pid) do
    Logger.debug(fn -> "handle_info(#{inspect(msg)}, #{inspect(s)})" end)

    s =
      if ref == timesync_ref do
        track =
          Map.put(s.timesync, :exit, reason)
          |> Map.put(:task, nil)
          |> Map.put(:status, :finished)

        Map.put(s, :timesync, track)
      end

    {:noreply, s}
  end

  def handle_info(unhandled_msg, _from, s) do
    log_unhandled("info", unhandled_msg)
    {:noreply, s}
  end

  defp config(key)
       when is_atom(key) do
    get_env(:mcp, Mqtt.Client) |> Keyword.get(key)
  end

  defp log_unhandled(type, message) do
    Logger.warn(fn -> "unhandled #{type} message #{inspect(message)}" end)
  end

  defp start_timesync_task(s) do
    task = Task.async(Timesync, :run, [timesync_opts()])

    Map.put(s, :timesync, %{task: task, status: :started})
  end

  defp timesync_opts do
    get_env(:mcp, Mqtt.Client, [])
    |> Keyword.get(:timesync, [])
    |> Enum.into(%{})
  end
end
