defmodule Mqtt.Handler do
  require Logger
  use Tortoise.Handler

  alias Mqtt.Client

  @build_env Application.compile_env(:mcp, :build_env)

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

  def handle_message([@build_env | _resr] = topic, payload, state) do
    Client.inbound_msg(topic, payload)

    {:ok, state}
  end

  def handle_message(topic, _payload, state) do
    Logger.warn([
      Module.split(__MODULE__),
      " mqtt msg recv'd mismatch, build_env: ",
      inspect(@build_env),
      " topic: ",
      inspect(Path.join(topic))
    ])

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
