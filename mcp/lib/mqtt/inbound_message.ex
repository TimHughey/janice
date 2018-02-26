defmodule Mqtt.InboundMessage do
  @moduledoc """
  """
  require Logger
  use GenServer
  import Application, only: [get_env: 2]
  import Process, only: [send_after: 3]

  alias Mqtt.Reading
  alias Fact.FreeRamStat
  alias Fact.RunMetric
  alias Fact.EngineMetric

  def start_link(s) do
    GenServer.start_link(Mqtt.InboundMessage, s, name: Mqtt.InboundMessage)
  end

  ## Callbacks

  def init(s)
      when is_map(s) do
    case Map.get(s, :autostart, false) do
      true -> send_after(self(), {:startup}, 0)
      false -> nil
    end

    s = Map.put_new(s, :log_reading, config(:log_reading))
    s = Map.put_new(s, :messages_dispatched, 0)
    s = Map.put_new(s, :json_log, nil)

    Logger.info("init()")

    {:ok, s}
  end

  @log_json_msg :log_json
  def log_json(args) when is_list(args) do
    rc = GenServer.call(Mqtt.InboundMessage, {@log_json_msg, args})
    if is_pid(rc), do: :log_open, else: :log_closed
  end

  # internal work functions

  def process(msg)
      when is_binary(msg) do
    GenServer.cast(Mqtt.InboundMessage, {:incoming_message, msg})
  end

  defp log_reading(%{}, false), do: nil

  defp log_reading(%{} = r, true) do
    if Reading.temperature?(r) do
      Logger.info(fn ->
        ~s(#{r.host} #{r.device} #{r.tc} #{r.tf})
      end)
    end

    if Reading.relhum?(r) do
      Logger.info(fn ->
        ~s(#{r.host} #{r.device} #{r.tc} #{r.tf} #{r.rh})
      end)
    end
  end

  # GenServer callbacks
  def handle_cast({:incoming_message, msg}, s)
      when is_binary(msg) and is_map(s) do
    {elapsed_us, task} =
      :timer.tc(fn ->
        task =
          if is_pid(s.json_log),
            do: Task.async(fn -> IO.puts(s.json_log, msg) end),
            else: nil

        Reading.decode(msg) |> decoded_msg(s)
        task
      end)

    s = %{s | messages_dispatched: s.messages_dispatched + 1}

    RunMetric.record(
      module: "#{__MODULE__}",
      application: "mercurial",
      metric: "msgs_dispatched",
      val: s.messages_dispatched
    )

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "mqtt_process_inbound_msg_us",
      device: "none",
      val: elapsed_us
    )

    if not is_nil(task), do: Task.await(task)
    {:noreply, s}
  end

  # open the json log if not already open
  def handle_call({@log_json_msg, opts}, _from, %{json_log: pid} = s) do
    log = Keyword.get(opts, :log, false)

    json_log =
      cond do
        # log start requested, it isn't open so open it
        log and is_nil(pid) ->
          {_, json_log} = File.open("/tmp/json.log", [:append, :utf8, :delayed_write])
          json_log

        # log stop requested and it is open, close it
        not log and is_pid(pid) ->
          File.close(pid)
          nil

        # log start requested and it's already open
        log and is_pid(pid) ->
          pid

        # log stop requested and it isn't open
        not log and is_nil(pid) ->
          nil
      end

    s = %{s | json_log: json_log}

    {:reply, json_log, s}
  end

  def handle_info({:startup}, s)
      when is_map(s) do
    send_after(self(), {:periodic_log}, config(:periodic_log_first_ms))
    Logger.info(fn -> "startup()" end)

    {:noreply, s}
  end

  def handle_info({:periodic_log}, s)
      when is_map(s) do
    Logger.info(fn -> "messages dispatched: #{s.messages_dispatched}" end)

    send_after(self(), {:periodic_log}, config(:periodic_log_ms))

    {:noreply, s}
  end

  defp config(key)
       when is_atom(key) do
    get_env(:mcp, Mqtt.InboundMessage) |> Keyword.get(key)
  end

  defp decoded_msg({:ok, r}, s) do
    log_reading(r, s.log_reading)

    # NOTE: we invoke the module / functions defined in the config
    #       to process incoming messages.  we also spin up a Task
    #       for the benefits of parallel processing.

    if Reading.startup?(r) do
      {mod, func} = config(:startup_msgs)
      Task.start(mod, func, [r])
    end

    if Reading.temperature?(r) || Reading.relhum?(r) do
      {mod, func} = config(:temperature_msgs)
      Task.start(mod, func, [r])
    end

    if Reading.switch?(r) do
      {mod, func} = config(:switch_msgs)
      Task.start(mod, func, [r])
    end

    if Reading.free_ram_stat?(r), do: FreeRamStat.record(remote_host: r.host, val: r.freeram)

    if Reading.engine_metric?(r), do: EngineMetric.record(r)

    nil
  end

  defp decoded_msg({:error, e}, _s) do
    Logger.warn(fn -> e end)
  end
end
