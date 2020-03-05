defmodule Mqtt.Reading do
  @moduledoc false

  require Logger

  alias Fact.EngineMetric

  alias Janice.TimeSupport

  alias Jason

  @boot_t "boot"
  @startup_t "startup"
  @temp_t "temp"
  @switch_t "switch"
  @relhum_t "relhum"
  @remote_run_t "remote_runtime"
  @mcr_stat_t "stats"
  @simple_text_t "text"
  @pwm_t "pwm"

  def boot?(%{type: @boot_t, host: host} = r) do
    Logger.debug(["detected boot message for ", inspect(host, pretty: true)])
    metadata?(r)
  end

  def boot?(%{}), do: false

  def check_metadata(%{} = r), do: metadata(r)

  @doc ~S"""
  Parse a JSON into a Reading

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr", "device": "ds/29.00000ffff",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.metadata?()
    true
  """
  def decode(json) do
    case Jason.decode(json, keys: :atoms) do
      {:ok, r} ->
        r =
          Map.put(r, :json, json)
          |> Map.put(:msg_recv_dt, TimeSupport.utc_now())
          |> check_metadata()

        {:ok, r}

      {:error, %Jason.DecodeError{data: data} = _e} ->
        opts = [binaries: :as_strings, pretty: true, limit: :infinity]
        {:error, "inbound msg parse failed:\n#{inspect(data, opts)}"}
    end
  end

  @doc ~S"""
  Does the Reading have the base metadata?

  NOTE: 1. As of 2017-10-01 we only support readings from mcr hosts with
           enforcement by checking the prefix of the host id
        2. We also check the mtime to confirm it is greater than epoch + 1 year.
           This is a safety check for situations where a host is reporting
           readings without the time set
        3. As of 2019-04-16 vsn is only sent as part of a startup mesg

   ##Examples:
    iex> json =
    ...>   ~s({"host":"mcr.macaddr", "device":"ds/28.00000ffff",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.metadata?()
    true

  """

  def metadata(%{mtime: mtime, type: type, host: <<"mcr.", _rest::binary>>} = r)
      when is_integer(mtime) and
             is_binary(type),
      do: Map.put(r, :metadata, :ok)

  def metadata(bad) do
    Logger.warn(["bad metadata ", inspect(bad, pretty: true)])
    %{metadata: :failed}
  end

  def metadata?(%{metadata: :ok}), do: true
  def metadata?(%{metadata: :failed}), do: false
  def metadata?(%{} = r), do: metadata(r) |> metadata?()

  @doc ~S"""
  Does the Reading have a good mtime?

  NOTE: 1. We check the mtime to confirm it is greater than epoch + 1 year.
           This is a safety check for situations where a host is reporting
           time sensitive readings without the time set

   ##Examples:
    iex> json =
    ...>   ~s({"host":"mcr.macaddr", "device":"ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.mtime_good?()
    true

    iex> json =
    ...>   ~s({"host": "other-macaddr",
    ...>       "mtime": 2106, "type": "startup"})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.mtime_good?()
    false
  """

  def mtime_good?(%{} = r) do
    # seconds since epoch for year 2
    epoch_first_year = 365 * 24 * 60 * 60 - 1

    r.mtime > epoch_first_year
  end

  @doc ~S"""
  Is the Reading a pwm?

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr",
    ...>       "mtime": 2106, "type": "pwm", "duty": 2048, "duty_min": 1,
    ...>       "duty_max": 4095})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.pwm?()
    true
  """
  def pwm?(%{type: @pwm_t} = r), do: metadata?(r)
  def pwm?(%{} = _r), do: false

  def remote_runtime?(%{type: @remote_run_t} = r), do: metadata?(r)
  def remote_runtime?(%{}), do: false

  @doc ~S"""
  Is the Reading a simple text?

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr",
    ...>       "mtime": 2106, "type": "text", "text": "simple message"})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.simple_text?()
    true
  """
  def simple_text?(%{text: _text} = r) do
    metadata?(r) and r.type === @simple_text_t
  end

  def simple_text?(%{} = _r), do: false

  @doc ~S"""
  Is the Reading a startup announcement?

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr",
    ...>       "mtime": 2106, "type": "startup"})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.startup?()
    true

    iex> json =
    ...>   ~s({"host":"mcr.macaddr", "device":"ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.startup?()
    false
  """
  def startup?(%{} = r) do
    metadata?(r) and r.type === @startup_t
  end

  @doc ~S"""
  Is the Reading a temperature?

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr", "device": "ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.temperature?()
    true
  """
  def temperature?(%{} = r) do
    tc = Map.get(r, :tc)
    tf = Map.get(r, :tf)

    check =
      (metadata?(r) and r.type === @temp_t and is_number(tc)) or is_number(tf)

    if check && Map.get(r, :log_reading, false) do
      Logger.info([
        inspect(r.host),
        " ",
        inspect(r.device),
        " ",
        inspect(r.tc),
        " ",
        inspect(r.tf)
      ])
    end

    check
  end

  @doc ~S"""
  Is the Reading a relative humidity?

   ##Examples:
   iex> json =
   ...>   ~s({"host": "mcr.macaddr",
   ...>       "device": "ds/29.0000", "mtime": 1506867918,
   ...>       "type": "relhum",
   ...>       "rh": 56.0})
   ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.relhum?()
   true
  """
  def relhum?(%{} = r) do
    rh = Map.get(r, :rh)
    check = metadata?(r) and r.type === @relhum_t and is_number(rh)

    if check && Map.get(r, :log_reading, false) do
      Logger.info([
        inspect(r.host),
        " ",
        inspect(r.device),
        " ",
        inspect(r.tc),
        " ",
        inspect(r.tf),
        " ",
        inspect(r.rh)
      ])
    end

    check
  end

  @doc ~S"""
  Is the Reading a switch?

   ##Examples:
    iex> json =
    ...>   ~s({"host": "mcr.macaddr",
    ...>       "device": "ds/29.0000", "mtime": 1506867918,
    ...>        "type": "switch",
    ...>        "states": [{"pio": 0, "state": true},
    ...>                      {"pio": 1, "state": false}],
    ...>        "pio_count": 2})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.switch?()
    true
  """
  def switch?(%{} = r) do
    device = Map.get(r, :device)
    states = Map.get(r, :states)
    pio_count = Map.get(r, :pio_count)

    metadata?(r) and r.type === @switch_t and is_binary(device) and
      is_list(states) and
      pio_count > 0
  end

  def free_ram_stat?(%{} = r) do
    freeram = Map.get(r, :freeram)
    metadata?(r) and r.type == @mcr_stat_t and is_integer(freeram)
  end

  def engine_metric?(%{} = r) do
    metadata?(r) and EngineMetric.valid?(r)
  end

  @doc ~S"""
  Is the Reading a cmdack?

   ##Examples:
    iex> json =
    ...>   ~s({ "host": "mcr.macaddr",
    ...>       "device": "ds/29.0000", "mtime": 1506867918,
    ...>        "type": "switch",
    ...>        "states": [{"pio": 0, "state": true},
    ...>                      {"pio": 1, "state": false}],
    ...>        "pio_count": 2,
    ...>        "cmdack": true, "latency_us": 10, "refid": "uuid"})
    ...> Jason.decode!(json, keys: :atoms) |> Mqtt.Reading.cmdack?()
    true
  """
  def cmdack?(%{} = r) do
    cmdack = Map.get(r, :cmdack)
    latency = Map.get(r, :latency_us)
    refid = Map.get(r, :refid)

    switch?(r) and cmdack === true and latency > 0 and is_binary(refid)
  end
end
