defmodule Mqtt.InboundMessage do
  @moduledoc false

  require Logger
  use GenServer
  import Application, only: [get_env: 2]
  import Process, only: [send_after: 3]
  import Janice.TimeSupport, only: [ms: 1]

  alias Fact.EngineMetric
  alias Fact.FreeRamStat

  # alias Fact.RunMetric

  alias Mqtt.Reading

  def start_link(s) do
    GenServer.start_link(Mqtt.InboundMessage, s, name: Mqtt.InboundMessage)
  end

  ## Callbacks

  def additional_message_flags(opts \\ []) when is_list(opts) do
    GenServer.call(__MODULE__, {:additional_message_flags, opts})
  end

  def init(s)
      when is_map(s) do
    Logger.debug(["init()"])

    periodic_log_default = [
      enable: true,
      first: {:secs, 1},
      repeat: {:mins, 15}
    ]

    s =
      Map.put_new(s, :log_reading, config(:log_reading))
      |> Map.put_new(:messages_dispatched, 0)
      |> Map.put_new(:temperature_msgs, config(:temperature_msgs))
      |> Map.put_new(:switch_msgs, config(:switch_msgs))
      |> Map.put_new(:remote_msgs, config(:remote_msgs))
      |> Map.put_new(:pwm_msgs, config(:pwm_msgs))
      |> Map.put_new(:periodic_log, config(:periodic_log, periodic_log_default))
      |> Map.put_new(
        :additional_message_flags,
        config(:additional_message_flags) |> Enum.into(%{})
      )

    if Map.get(s, :autostart, false) do
      first = s.periodic_log |> Keyword.get(:first)
      send_after(Mqtt.InboundMessage, {:periodic, :first}, ms(first))
    end

    {:ok, s}
  end

  # internal work functions

  def process(%{direction: _, payload: payload}, opts \\ [])
      when is_bitstring(payload) and is_list(opts) do
    async = Keyword.get(opts, :async, true)

    if async,
      do:
        GenServer.cast(Mqtt.InboundMessage, {:incoming_message, payload, opts}),
      else:
        GenServer.call(Mqtt.InboundMessage, {:incoming_message, payload, opts})
  end

  # GenServer callbacks
  def handle_call({:additional_message_flags, opts}, _from, s) do
    set_flags = Keyword.get(opts, :set, nil)
    merge_flags = Keyword.get(opts, :merge, nil)

    cond do
      opts == [] ->
        {:reply, s.additional_message_flags, s}

      is_list(set_flags) ->
        s = Map.put(s, :additional_flags, Enum.into(set_flags, %{}))
        {:reply, {:ok, s.additional_flags}, s}

      is_list(merge_flags) ->
        flags =
          Map.merge(s.additional_message_flags, Enum.into(merge_flags, %{}))

        s = Map.put(s, :additional_flags, flags)
        {:reply, {:ok, s.additional_flags}, s}

      true ->
        {:reply, :bad_opts, s}
    end
  end

  def handle_call({:incoming_message, msg, opts}, _from, s) do
    {:reply, :ok, incoming_msg(msg, s, opts)}
  end

  def handle_call(catch_all, _from, s) do
    Logger.warn(["unknown handle_call(", inspect(catch_all, pretty: true), ")"])
    {:reply, {:bad_msg}, s}
  end

  def handle_cast({:incoming_message, msg, opts}, s)
      when is_binary(msg) and is_map(s) do
    {:noreply, incoming_msg(msg, s, opts)}
  end

  def handle_cast(catch_all, s) do
    Logger.warn(["unknown handle_cast(", inspect(catch_all, pretty: true), ")"])
    {:noreply, s}
  end

  def handle_info({:periodic, flag}, s)
      when is_map(s) do
    log = Kernel.get_in(s, [:periodic_log, :enable])
    repeat = Kernel.get_in(s, [:periodic_log, :repeat])

    msg_text = fn flag, x, repeat ->
      a = if x == 0, do: ["no "], else: ["#{x} "]

      b =
        if flag == :first,
          do: [" (future reports every ", "#{repeat})"],
          else: []

      [a, "messages dispatched", b]
    end

    log && Logger.info(msg_text.(flag, s.messages_dispatched, repeat))

    send_after(self(), {:periodic, :none}, ms(repeat))

    {:noreply, s}
  end

  def handle_info(catch_all, s) do
    Logger.warn(["unknown handle_info(", inspect(catch_all, pretty: true), ")"])
    {:noreply, s}
  end

  defp config(key, default \\ [])
       when is_atom(key) do
    get_env(:mcp, Mqtt.InboundMessage) |> Keyword.get(key, default)
  end

  defp incoming_msg(msg, s, opts) do
    msg |> Reading.decode() |> msg_decode(s, opts)

    %{s | messages_dispatched: s.messages_dispatched + 1}
  end

  defp msg_ensure_flags(%{} = s, %{} = r, opts) when is_list(opts) do
    # downstream modules and functions use flags (as part of the reading)
    # for logging and to control if expensive runtime metrics are collected
    Map.put_new(r, :log_reading, Map.get(r, :log, s.log_reading))
    |> Map.put_new(
      :runtime_metrics,
      Keyword.get(opts, :runtime_metrics, false)
    )
    |> Map.merge(s.additional_message_flags)
  end

  defp msg_decode({:ok, %{metadata: :fail}}, _s, _opts), do: nil

  defp msg_decode({:ok, %{metadata: :ok} = r}, s, opts) when is_list(opts) do
    # NOTE: we invoke the module / functions defined in the config
    #       to process incoming messages.  if the async opt is present we'll
    #       also spin up a task to take advantage of parallel processing

    r = msg_ensure_flags(s, r, opts)

    {mod, func} = msg_process_external(s, r)

    async = Keyword.get(opts, :async, true)

    cond do
      # if msg_handler does not find a mod and function configured to
      # process the msg then try to process it locally

      is_nil(mod) or is_nil(func) ->
        msg_process_locally(r)
        nil

      :missing == mod ->
        Logger.warn([
          "missing configuration for reading type: ",
          inspect(r.type, pretty: true)
        ])

      # reading needs to be processed, should we do it async?
      async ->
        Task.start(mod, func, [r])

      # process msg inline
      true ->
        apply(mod, func, [r])
    end

    nil
  end

  defp msg_decode({:error, e}, _s, _opts),
    do: Logger.warn(["msg_decode() error: ", inspect(e, pretty: true)])

  defp msg_process_external(%{} = s, %{} = r) do
    missing = {:missing, :missing}

    cond do
      Reading.boot?(r) ->
        Map.get(s, :remote_msgs, missing)

      Reading.startup?(r) ->
        Map.get(s, :remote_msgs, missing)

      Reading.remote_runtime?(r) ->
        Map.get(s, :remote_msgs, missing)

      Reading.relhum?(r) ->
        Map.get(s, :temperature_msgs, missing)

      Reading.temperature?(r) ->
        Map.get(s, :temperature_msgs, missing)

      Reading.switch?(r) ->
        Map.get(s, :switch_msgs, missing)

      Reading.pwm?(r) ->
        Map.get(s, :pwm_msgs, missing)

      true ->
        {nil, nil}
    end
  end

  defp msg_process_locally(%{} = r) do
    cond do
      Reading.free_ram_stat?(r) ->
        Map.put_new(r, :record, r.runtime_metrics) |> FreeRamStat.record()

      Reading.engine_metric?(r) ->
        Map.put_new(r, :record, r.runtime_metrics) |> EngineMetric.record()

      Reading.simple_text?(r) ->
        log = Map.get(r, :log, true)
        log && Logger.info([r.name, " ", r.text])

      true ->
        Logger.warn([r.name, " unhandled reading ", inspect(r, pretty: true)])
    end

    nil
  end
end
