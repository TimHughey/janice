defmodule Mqtt.Handler do
  require Logger
  use Tortoise.Handler

  alias Mqtt.Client

  def init(args) do
    {:ok, args}
  end

  def connection(:up, state) do
    # `status` will be either `:up` or `:down`; you can use this to
    # inform the rest of your system if the connection is currently
    # open or closed; tortoise should be busy reconnecting if you get
    # a `:down`
    Client.connected()

    {:ok, state}
  end

  def connection(:down, state) do
    Client.disconnected()

    {:ok, state}
  end

  #  topic filter room/+/temp
  def handle_message(["room", _room, "temp"], _payload, state) do
    # :ok = Temperature.record(room, payload)
    {:ok, state}
  end

  def handle_message(topic, payload, state) do
    # unhandled message! You will crash if you subscribe to something
    # and you don't have a 'catch all' matcher; crashing on unexpected
    # messages could be a strategy though.
    Client.inbound_msg(topic, payload)

    {:ok, state}
  end

  def subscription(status, topic_filter, state) do
    log = Keyword.get(state, :log_subscriptions, false)

    log &&
      Logger.warn([
        "subscription(): status(",
        inspect(status, pretty: true),
        ") topic(",
        inspect(topic_filter, pretty: true),
        ")"
      ])

    {:ok, state}
  end

  def terminate(reason, _state) do
    # tortoise doesn't care about what you return from terminate/2,
    # that is in alignment with other behaviours that implement a
    # terminate-callback
    Logger.warn(["Tortoise terminate: ", inspect(reason)])
    :ok
  end
end
