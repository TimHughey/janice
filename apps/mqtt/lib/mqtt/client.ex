defmodule Mqtt.Client do
  use GenServer
  use GenMQTT

  def start_link(pid, opts \\ []) do
    GenMQTT.start_link(__MODULE__, pid, opts)
  end

  def on_connect(state) do
    send state, :connected
    {:ok, state}
  end

  def on_disconnect(state) do
    send state, :disconnected
    {:ok, state}
  end

  def on_publish(topic, message, state) do
    send state, {:published, self(), topic, message}
    {:ok, state}
  end

  def on_subscribe(subscription, state) do
    send state, {:subscribed, subscription}
    {:ok, state}
  end

  def on_unsubscribe(subscription, state) do
    send state, {:unsubscribed, subscription}
    {:ok, state}
  end

  def terminate(:normal, state) do
    send state, :shutdown
    :ok
  end
  def terminate(_reason, _state) do
    :ok
  end
end
