defmodule Mqtt.Client do
@moduledoc """
"""
require Logger
use GenServer
alias Hulaaki.Connection
alias Hulaaki.Message

alias Mqtt.Client
alias Mcp.Reading

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

def start_link(state) do
  GenServer.start_link(__MODULE__, state, name: __MODULE__)
end

## Callbacks

def init(state) when is_map(state) do
  Logger.info("Mqtt.Client.init()")

  state =
        state
        |> Map.put(:packet_id, 1)
        |> Map.put(:keep_alive_interval, nil)
        |> Map.put(:keep_alive_timer_ref, nil)
        |> Map.put(:ping_response_timeout_interval, nil)
        |> Map.put(:ping_response_timer_ref, nil)

  {:ok, state}
end

def connect do
  GenServer.call(__MODULE__, :connect)
end

def get_state do
  GenServer.call(__MODULE__, :state)
end

def report_subscribe do
  opts = Application.get_env(:mcp, Mqtt.Client) |> Keyword.get(:feeds)
  subscribe(opts)
end

def subscribe(opts) do
  GenServer.call(__MODULE__, {:subscribe, opts})
end

def handle_call(:state, _from, state) do
  {:reply, state, state}
end

def handle_call(:connect, _from, s) do
  opts = Application.get_env(:mcp, Mqtt.Client) |> Keyword.get(:broker)

  {:ok, conn_pid} = Connection.start_link(self())

  host          = opts |> Keyword.fetch!(:host)
  port          = opts |> Keyword.fetch!(:port)
  timeout       = opts |> Keyword.get(:timeout, 100)
  ssl           = opts |> Keyword.get(:ssl, false)

  client_id     = opts |> Keyword.fetch!(:client_id)
  username      = opts |> Keyword.get(:username, "")
  password      = opts |> Keyword.get(:password, "")
  will_topic    = opts |> Keyword.get(:will_topic, "")
  will_message  = opts |> Keyword.get(:will_message, "")
  will_qos      = opts |> Keyword.get(:will_qos, 0)
  will_retain   = opts |> Keyword.get(:will_retain, 0)
  clean_session = opts |> Keyword.get(:clean_session, 1)
  keep_alive    = opts |> Keyword.get(:keep_alive, 100)

  # arbritary : based off recommendation on MQTT 3.1.1 spec Line 542/543
  ping_response_timeout = keep_alive * 2

  message = Message.connect(client_id, username, password,
                            will_topic, will_message, will_qos,
                            will_retain, clean_session, keep_alive)

  s = Map.merge(%{connection: conn_pid}, s)

  connect_opts = [host: host, port: port, timeout: timeout, ssl: ssl]

  s = %{s | keep_alive_interval: keep_alive * 1000,
            ping_response_timeout_interval: ping_response_timeout * 1000}

  case s.connection |> Connection.connect(message, connect_opts) do
    :ok -> {:reply, {:ok, s}, s}
    {:error, reason} -> {:reply, {:error, reason}, s}
  end
end

def handle_call({:subscribe, opts}, _from, state) do
  id     = state.packet_id
  topics = opts |> Keyword.fetch!(:topics)
  qoses  = opts |> Keyword.fetch!(:qoses)

  message = Message.subscribe(id, topics, qoses)

  :ok = state.connection |> Connection.subscribe(message)
  state = update_packet_id(state)
  {:reply, :ok, state}
end

def handle_call(:pop, _from, [h | t]) do
  {:reply, h, t}
end

def handle_cast({:push, h}, t) do
  {:noreply, [h | t]}
end

def handle_info({:sent, %Message.Connect{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_connect [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.ConnAck{} = message}, state) do
  on_connect_ack [message: message, state: state]
  {:noreply, state}
end

def handle_info({:sent, %Message.Publish{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_publish [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.Publish{qos: qos} = message}, state) do
  on_subscribed_publish [message: message, state: state]

  case qos do
    1 ->
      message = Message.publish_ack message.id
      :ok = state.connection |> Connection.publish_ack(message)
    _ ->
      # unsure about supporting qos 2 yet
  end

  {:noreply, state}
end

def handle_info({:sent, %Message.PubAck{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_subscribed_publish_ack [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.PubRec{} = message}, state) do
  on_publish_receive [message: message, state: state]

  message = Message.publish_release message.id
  :ok = state.connection |> Connection.publish_release(message)

  {:noreply, state}
end

def handle_info({:sent, %Message.PubRel{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_publish_release [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.PubComp{} = message}, state) do
  on_publish_complete [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.PubAck{} = message}, state) do
  on_publish_ack [message: message, state: state]
  {:noreply, state}
end

def handle_info({:sent, %Message.Subscribe{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_subscribe [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.SubAck{} = message}, state) do
  on_subscribe_ack [message: message, state: state]
  {:noreply, state}
end

def handle_info({:sent, %Message.Unsubscribe{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_unsubscribe [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.UnsubAck{} = message}, state) do
  on_unsubscribe_ack [message: message, state: state]
  {:noreply, state}
end

def handle_info({:sent, %Message.PingReq{} = message}, state) do
  state = reset_keep_alive_timer(state)
  state = reset_ping_response_timer(state)
  on_ping [message: message, state: state]
  {:noreply, state}
end

def handle_info({:received, %Message.PingResp{} = message}, state) do
  state = cancel_ping_response_timer(state)
  on_ping_response [message: message, state: state]
  {:noreply, state}
end

def handle_info({:sent, %Message.Disconnect{} = message}, state) do
  state = reset_keep_alive_timer(state)
  on_disconnect [message: message, state: state]
  {:noreply, state}
end

def handle_info({:keep_alive}, state) do
  :ok = state.connection |> Connection.ping
  {:noreply, state}
end

def handle_info({:ping_response_timeout}, state) do
  on_ping_response_timeout [message: nil, state: state]
  {:noreply, state}
end

def on_connect([message: message, state: state]) do
  Logger.info("on_connect")
  true
end

def on_connect_ack([message: message, state: state]) do
  Logger.info("on_connect_ack")
  true
end

def on_subscribed_publish([message: %Message.Publish{} = data, state: s]) do
  Logger.debug fn -> "message: #{data.message}" end
  r = Reading.decode!(data.message)
  log_reading(r)
  true
end

defp log_reading(%Reading{} = r) do
  if Reading.temperature?(r) do
    Logger.info fn ->
      ~s(#{r.host} #{r.device} #{r.friendly_name} #{r.tc} #{r.tf})
    end
  end

  if Reading.relhum?(r) do
    Logger.info fn ->
      ~s(#{r.host} #{r.device} #{r.friendly_name} #{r.tc} #{r.tf} #{r.rh})
    end
  end
end

def on_publish([message: message, state: state]), do: true
def on_publish_receive([message: message, state: state]), do: true
def on_publish_release([message: message, state: state]), do: true
def on_publish_complete([message: message, state: state]), do: true
def on_publish_ack([message: message, state: state]), do: true
def on_subscribe([message: message, state: state]), do: true
def on_subscribe_ack([message: message, state: state]), do: true
def on_unsubscribe([message: message, state: state]), do: true
def on_unsubscribe_ack([message: message, state: state]), do: true

def on_subscribed_publish_ack([message: message, state: state]), do: true
def on_ping([message: message, state: state]), do: true
def on_ping_response([message: message, state: state]), do: true
def on_ping_response_timeout([message: message, state: state]), do: true
def on_disconnect([message: message, state: state]), do: true

## Private functions
defp reset_keep_alive_timer(%{keep_alive_interval: kai,
                              keep_alive_timer_ref: katr} = state) do
 if katr, do: Process.cancel_timer(katr)
 katr = Process.send_after(self(), {:keep_alive}, kai)
 %{state | keep_alive_timer_ref: katr}
end

defp reset_ping_response_timer(%{ping_response_timeout_interval: prti,
                                ping_response_timer_ref: prtr} = state) do
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
  %{state | packet_id: (packet_id + 1)}
end

end
