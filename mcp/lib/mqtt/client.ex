defmodule Mqtt.Client do
  @moduledoc """
  """
  require Logger
  use GenServer

  import Application, only: [get_env: 2, get_env: 3]
  alias Fact.RunMetric
  alias Mqtt.Timesync

  #  def child_spec(opts) do
  #
  #    %{
  #      id: Mercurial.Mqtt.Client,
  #      start: {Mercurial.Mqtt.Client, :start_link, [opts]},
  #      restart: :permanent,
  #      shutdown: 5000,
  #      type: :supervisor
  #    }
  #  end

  def start_link(s) when is_map(s) do
    GenServer.start_link(__MODULE__, s, name: __MODULE__)
  end

  ## Callbacks

  def init(s) when is_map(s) do
    Logger.info(fn -> "init()" end)

    # pass the same initial state (opts) to Mqtt.InboundMessage and allow it to
    # figure out what to do.  ultimately all that is passed is autostart which will
    # be the same
    {:ok, dispatcher_pid} = Mqtt.InboundMessage.start_link(s)

    if Map.get(s, :autostart, false) do
      # prepare the opts that will be passed to emqttc (erlang) including logger config and
      # start it up
      opts = config(:broker)
      opts = Keyword.merge([logger: :warning], opts)
      {:ok, mqtt_pid} = :emqttc.start_link(opts)

      # start-up MsgSaver
      {:ok, msgsave_pid} = MessageSave.start_link(s)

      # populate the state and construct init() return
      s = Map.put_new(s, :dispatcher_pid, dispatcher_pid)
      s = Map.put_new(s, :mqtt_pid, mqtt_pid)
      s = Map.put_new(s, :messagesave_pid, msgsave_pid)

      {:ok, s}
    else
      # when we don't autostart the mqtt pid will be nil
      s = Map.put_new(s, :dispatcher_pid, dispatcher_pid)
      s = Map.put_new(s, :mqtt_pid, nil)

      {:ok, s}
    end

    # init() return is calculated above in if block
    # at the conclusion of init() we have a running InboundMessage GenServer and
    # potentially a running emqttc (actual connection to MQTT)
  end

  def report_subscribe do
    feed = get_env(:mcp, :feeds, []) |> Keyword.get(:rpt, nil)
    subscribe(feed)
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
    Logger.warn(fn -> "subscribe feed doesn't make sense, got #{inspect(feed)}" end)
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

    if is_nil(feed) or is_nil(payload) do
      Logger.warn(fn ->
        "can't publish: feed=#{inspect(feed)} payload=#{inspect(payload)}"
      end)

      Logger.warn(fn -> "hint: check :feeds are defined in the configuration" end)

      :ok
    else
      Logger.debug(fn -> "outbound: #{payload}" end)
      MessageSave.save(:out, payload)
      GenServer.call(__MODULE__, {:publish, feed, payload, pub_opts})
    end
  end

  def publish_switch_cmd(message) do
    {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, {nil, nil})
    payload = message
    pub_opts = [qos]

    opts = [feed: feed, message: payload, pub_opts: pub_opts]
    publish(opts)
  end

  def handle_call({:publish, feed, payload, pub_opts}, _from, s)
      when is_binary(feed) and is_binary(payload) and is_list(pub_opts) do
    res = :emqttc.publish(s.mqtt_pid, feed, payload, pub_opts)
    {:reply, res, s}
  end

  def handle_call({:subscribe, feed}, _from, s)
      when is_tuple(feed) do
    Logger.info(fn -> "subscribing to #{inspect(feed)}" end)

    res = :emqttc.subscribe(s.mqtt_pid, feed)
    {:reply, res, s}
  end

  def handle_call({:timesync_msg}, _from, s) do
    {feed, qos} = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, {nil, nil})

    if not is_nil(feed) and not is_nil(qos) do
      payload = Timesync.new_cmd() |> Timesync.json()
      pub_opts = [qos]

      res = :emqttc.publish(s.mqtt_pid, feed, payload, pub_opts)
      {:reply, {res}, s}
    else
      Logger.warn(fn -> "can't send timesync, feed configuration missing" end)
      {:reply, {:failed}, s}
    end
  end

  def handle_call(unhandled_msg, _from, s) do
    log_unhandled("call", unhandled_msg)
    {:reply, :ok, s}
  end

  def handle_cast(unhandled_msg, _from, s) do
    log_unhandled("cast", unhandled_msg)
    {:noreply, s}
  end

  def handle_info({:mqttc, _pid, :connected}, s) do
    s = Map.put(s, :connected, true)
    Logger.info(fn -> "mqtt endpoint connected" end)

    # subscribe to the report feed
    feed = get_env(:mcp, :feeds, []) |> Keyword.get(:rpt, nil)
    res = :emqttc.subscribe(s.mqtt_pid, feed)

    s = Map.put(s, :rpt_feed_subscribed, res)

    s = start_timesync_task(s)

    {:noreply, s}
  end

  def handle_info({:mqttc, _pid, :disconnected}, s) do
    Logger.warn(fn -> "mqtt endpoint disconnected" end)
    s = Map.put(s, :connected, false)
    {:noreply, s}
  end

  def handle_info({:publish, _topic, message}, s) do
    {elapsed_us, _res} =
      :timer.tc(fn ->
        MessageSave.save(:in, message)
        Mqtt.InboundMessage.process(message)
      end)

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "process_msg_us",
      device: "none",
      val: elapsed_us
    )

    {:noreply, s}
  end

  def handle_info({ref, result} = msg, %{timesync: %{task: %{ref: timesync_ref}}} = s)
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
          Map.put(s.timesync, :exit, reason) |> Map.put(:task, nil)
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
    get_env(:mcp, Mqtt.Client, []) |> Keyword.get(:timesync, []) |> Enum.into(%{})
  end
end
