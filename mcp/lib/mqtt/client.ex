defmodule Mqtt.Client do
  @moduledoc """
  """
  require Logger
  use GenServer

  alias Hulaaki.Connection
  alias Hulaaki.Message

  import Application, only: [get_env: 2, get_env: 3]
  import Process, only: [send_after: 3]

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
    s =
      s
      |> Map.put(:packet_id, 1)
      |> Map.put(:keep_alive_interval, nil)
      |> Map.put(:keep_alive_timer_ref, nil)
      |> Map.put(:ping_response_timeout_interval, nil)
      |> Map.put(:ping_response_timer_ref, nil)
      |> Map.put(:connected, false)

    case Map.get(s, :autostart, false) do
      true -> send_after(self(), {:startup}, 0)
      false -> nil
    end

    Logger.info("init()")

    {:ok, s}
  end

  def connect do
    GenServer.call(__MODULE__, :connect)
  end

  def get_state do
    GenServer.call(__MODULE__, :state)
  end

  def report_subscribe do
    opts = config(:feeds)
    subscribe(opts)
  end

  def subscribe(opts) do
    GenServer.call(__MODULE__, {:subscribe, opts})
  end

  def publish(opts) do
    GenServer.call(__MODULE__, {:publish, opts})
  end

  def publish_switch_cmd(message) do
    feed = get_env(:mcp, :feeds, []) |> Keyword.get(:cmd, nil)

    if feed do
      opts = [topic: feed, message: message, dup: 0, qos: 0, retain: 0]
      publish(opts)
    else
      :cmd_feed_config_missing
    end
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:connect, _from, s) do
    case do_connect(s) do
      :ok -> {:reply, {:ok, s}, s}
      {:error, reason} -> {:reply, {:error, reason}, s}
    end
  end

  def handle_call({:subscribe, opts}, _from, s) do
    do_subscribe(s, opts)
  end

  # catch the case when there isn't an active connection
  def handle_call({:publish, opts}, _from, %{connected: false} = s) do
    msg = opts |> Keyword.fetch!(:message)

    MessageSave.save(:out, msg, true)

    config(:log_dropped_msgs) &&
      Logger.warn(fn ->
        ~s/not connected, dropping msg #{msg}/
      end)

    {:reply, :ok, s}
  end

  def handle_call({:publish, opts}, _from, %{connection: _} = s) do
    topic = opts |> Keyword.fetch!(:topic)
    msg = opts |> Keyword.fetch!(:message)
    dup = opts |> Keyword.fetch!(:dup)
    qos = opts |> Keyword.fetch!(:qos)
    retain = opts |> Keyword.fetch!(:retain)

    Logger.debug(fn -> "outbound: #{msg}" end)
    MessageSave.save(:out, msg)

    {message, s} =
      case qos do
        0 ->
          {Message.publish(topic, msg, dup, qos, retain), s}

        _ ->
          id = s.packet_id
          s = update_packet_id(s)
          {Message.publish(id, topic, msg, dup, qos, retain), s}
      end

    :ok = s.connection |> Connection.publish(message)
    {:reply, :ok, s}
  end

  def handle_call(:pop, _from, [h | t]) do
    {:reply, h, t}
  end

  def handle_cast({:push, h}, t) do
    {:noreply, [h | t]}
  end

  def handle_info({:startup}, s) when is_map(s) do
    opts = config(:feeds)

    {s, conn_result} = do_connect(s)

    case conn_result do
      :ok ->
        do_subscribe(s, opts)

      {:error, _reason} ->
        Logger.warn(fn -> "will retry connection..." end)
        send_after(self(), {:startup}, 1000)
    end

    {:noreply, s}
  end

  def handle_info({:sent, %Message.Connect{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_connect(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.ConnAck{} = message}, state) do
    on_connect_ack(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:sent, %Message.Publish{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_publish(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.Publish{qos: qos} = message}, state) do
    on_subscribed_publish(message: message, state: state)

    case qos do
      1 ->
        message = Message.publish_ack(message.id)
        :ok = state.connection |> Connection.publish_ack(message)

      _ ->
        nil
        # unsure about supporting qos 2 yet
    end

    {:noreply, state}
  end

  def handle_info({:sent, %Message.PubAck{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_subscribed_publish_ack(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.PubRec{} = message}, state) do
    on_publish_receive(message: message, state: state)

    message = Message.publish_release(message.id)
    :ok = state.connection |> Connection.publish_release(message)

    {:noreply, state}
  end

  def handle_info({:sent, %Message.PubRel{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_publish_release(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.PubComp{} = message}, state) do
    on_publish_complete(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.PubAck{} = message}, state) do
    on_publish_ack(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:sent, %Message.Subscribe{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_subscribe(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.SubAck{} = message}, state) do
    on_subscribe_ack(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:sent, %Message.Unsubscribe{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_unsubscribe(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.UnsubAck{} = message}, state) do
    on_unsubscribe_ack(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:sent, %Message.PingReq{} = message}, state) do
    state = reset_keep_alive_timer(state)
    state = reset_ping_response_timer(state)
    on_ping(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:received, %Message.PingResp{} = message}, state) do
    state = cancel_ping_response_timer(state)
    on_ping_response(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:sent, %Message.Disconnect{} = message}, state) do
    state = reset_keep_alive_timer(state)
    on_disconnect(message: message, state: state)
    {:noreply, state}
  end

  def handle_info({:keep_alive}, state) do
    :ok = state.connection |> Connection.ping()
    {:noreply, state}
  end

  def handle_info({:ping_response_timeout}, state) do
    on_ping_response_timeout(message: nil, state: state)
    {:noreply, state}
  end

  def on_connect(message: _message, state: _state) do
    # Logger.info("on_connect")
    true
  end

  def on_connect_ack(message: _message, state: _state) do
    # Logger.info("on_connect_ack")
    true
  end

  def on_subscribed_publish(message: %Message.Publish{} = data, state: _s) do
    msg = data.message
    MessageSave.save(:in, msg)
    # Logger.info fn -> "#{msg}" end

    GenServer.cast(Dispatcher.InboundMessage, {:incoming_message, msg})
    true
  end

  def on_publish(message: _message, state: _state), do: true
  def on_publish_receive(message: _message, state: _state), do: true
  def on_publish_release(message: _message, state: _state), do: true
  def on_publish_complete(message: _message, state: _state), do: true
  def on_publish_ack(message: _message, state: _state), do: true
  def on_subscribe(message: _message, state: _state), do: true
  def on_subscribe_ack(message: _message, state: _state), do: true
  def on_unsubscribe(message: _message, state: _state), do: true
  def on_unsubscribe_ack(message: _message, state: _state), do: true

  def on_subscribed_publish_ack(message: _message, state: _state), do: true
  def on_ping(message: _message, state: _state), do: true
  def on_ping_response(message: _message, state: _state), do: true
  def on_ping_response_timeout(message: _message, state: _state), do: true
  def on_disconnect(message: _message, state: _state), do: true

  defp do_connect(s) when is_map(s) do
    Logger.info(fn -> "attemping to create connection to MQTT" end)
    opts = config(:broker)

    {:ok, conn_pid} = Connection.start_link(self())
    Logger.info(fn -> "created connection #{inspect(conn_pid)}" end)

    host = opts |> Keyword.fetch!(:host)
    port = opts |> Keyword.fetch!(:port)
    timeout = opts |> Keyword.get(:timeout, 100)
    ssl = opts |> Keyword.get(:ssl, false)

    client_id = opts |> Keyword.fetch!(:client_id)
    username = opts |> Keyword.get(:username, "")
    password = opts |> Keyword.get(:password, "")
    will_topic = opts |> Keyword.get(:will_topic, "")
    will_message = opts |> Keyword.get(:will_message, "")
    will_qos = opts |> Keyword.get(:will_qos, 0)
    will_retain = opts |> Keyword.get(:will_retain, 0)
    clean_session = opts |> Keyword.get(:clean_session, 0)
    keep_alive = opts |> Keyword.get(:keep_alive, 100)

    # arbritary : based off recommendation on MQTT 3.1.1 spec Line 542/543
    ping_response_timeout = keep_alive * 2

    message =
      Message.connect(
        client_id,
        username,
        password,
        will_topic,
        will_message,
        will_qos,
        will_retain,
        clean_session,
        keep_alive
      )

    connect_opts = [host: host, port: port, timeout: timeout, ssl: ssl]

    s = %{
      s
      | keep_alive_interval: keep_alive * 1000,
        ping_response_timeout_interval: ping_response_timeout * 1000
    }

    result = Connection.connect(conn_pid, message, connect_opts)

    case result do
      :ok ->
        Logger.info(fn -> "connection established" end)
        s = Map.merge(%{connection: conn_pid}, s)
        s = Map.put(s, :connected, true)
        {s, :ok}

      {:error, reason} ->
        # kill off the connection that was just started since it's not valid

        Logger.warn(fn -> "client connect " <> "failed, reason=#{reason}" end)

        s = Map.merge(%{connection: nil}, s)
        s = Map.put(s, :connected, false)
        {s, {:error, reason}}
    end
  end

  defp do_subscribe(s, opts) when is_map(s) do
    id = s.packet_id
    topics = opts |> Keyword.fetch!(:topics)
    qoses = opts |> Keyword.fetch!(:qoses)

    message = Message.subscribe(id, topics, qoses)

    :ok = s.connection |> Connection.subscribe(message)
    s = s |> update_packet_id()
    {:reply, :ok, s}
  end

  ## Private functions
  defp reset_keep_alive_timer(%{keep_alive_interval: kai, keep_alive_timer_ref: katr} = state) do
    if katr, do: Process.cancel_timer(katr)
    katr = Process.send_after(self(), {:keep_alive}, kai)
    %{state | keep_alive_timer_ref: katr}
  end

  defp reset_ping_response_timer(
         %{ping_response_timeout_interval: prti, ping_response_timer_ref: prtr} = state
       ) do
    if prtr, do: Process.cancel_timer(prtr)
    prtr = Process.send_after(self(), {:ping_response_timeout}, prti)
    %{state | ping_response_timer_ref: prtr}
  end

  defp cancel_ping_response_timer(%{ping_response_timer_ref: prtr} = state) do
    if prtr, do: Process.cancel_timer(prtr)
    %{state | ping_response_timer_ref: nil}
  end

  defp update_packet_id(%{packet_id: 65_535} = state) do
    %{state | packet_id: 1}
  end

  defp update_packet_id(%{packet_id: packet_id} = state) do
    %{state | packet_id: packet_id + 1}
  end

  defp config(key)
       when is_atom(key) do
    get_env(:mcp, Mqtt.Client) |> Keyword.get(key)
  end
end
