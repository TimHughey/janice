defmodule Mqtt.Reading do
  @moduledoc """
  """

  alias __MODULE__
  use Timex
  require Logger

  alias Poison

  @undef "undef"
  @startup_t "startup"
  @temp_t "temp"
  @switch_t "switch"
  @relhum_t "relhum"
  @mcr_stat_t "stats"

  @derive [Poison.Encoder]
  defstruct version: "no version",
            vsn: "no vsn",
            host: @undef,
            device: nil,
            type: nil,
            mtime: 0,
            tc: nil,
            tf: nil,
            rh: nil,
            pio_count: 0,
            states: nil,
            cmdack: false,
            latency: 0,
            refid: nil,
            json: nil,
            msg_recv_dt: Timex.now(),
            freeram: nil

  @doc ~S"""
  Parse a JSON into a Reading

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host": "mcr-macaddr", "device": "ds/29.00000ffff",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.metadata?()
    true
  """
  def decode(json)
      when is_binary(json) do
    case Poison.decode(json, keys: :atoms, as: %Mqtt.Reading{}) do
      {:ok, r} ->
        r = Map.put(r, :json, json) |> Map.put(:msg_recv_dt, Timex.now())
        {:ok, r}

      {:error, e} ->
        {:error, "inbound msg parse failed #{inspect(e)}"}
    end
  end

  @doc ~S"""
  Does the Reading have the base metadata?

  NOTE: 1. As of 2017-10-01 we only support readings from mcr hosts with
           enforcement by checking the prefix of the host id
        2. We also check the mtime to confirm it is greater than epoch + 1 year.
           This is a safety check for situations where a host is reporting
           readings without the time set

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host":"mcr-macaddr", "device":"ds/28.00000ffff",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.metadata?()
    true

    iex> json =
    ...>   ~s({"vsn": 0, "host": "other-macaddr", "device": "ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.metadata?()
    false
  """
  def metadata?(%Reading{} = r) do
    is_integer(r.mtime) and String.starts_with?(r.host, "mcr") and is_binary(r.type)
  end

  @doc ~S"""
  Does the Reading have a good mtime?

  NOTE: 1. We check the mtime to confirm it is greater than epoch + 1 year.
           This is a safety check for situations where a host is reporting
           time sensitive readings without the time set

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host":"mcr-macaddr", "device":"ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.mtime_good?()
    true

    iex> json =
    ...>   ~s({"vsn": 0, "host": "other-macaddr",
    ...>       "mtime": 2106, "type": "startup"})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.mtime_good?()
    false
  """

  def mtime_good?(%Reading{} = r) do
    # seconds since epoch for year 2
    epoch_first_year = 365 * 24 * 60 * 60 - 1

    r.mtime > epoch_first_year
  end

  @doc ~S"""
  Is the Reading a startup announcement?

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host": "mcr-macaddr",
    ...>       "mtime": 2106, "type": "startup"})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.startup?()
    true

    iex> json =
    ...>   ~s({"vsn": 1, "host":"mcr-macaddr", "device":"ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.startup?()
    false
  """
  def startup?(%Reading{} = r) do
    metadata?(r) and r.type === @startup_t
  end

  @doc ~S"""
  Is the Reading a temperature?

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host": "mcr-macaddr", "device": "ds/28.0000",
    ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.temperature?()
    true
  """
  def temperature?(%Reading{} = r) do
    metadata?(r) and r.type === @temp_t and is_number(r.tc) and is_number(r.tf)
  end

  @doc ~S"""
  Is the Reading a relative humidity?

   ##Examples:
   iex> json =
   ...>   ~s({"vsn": 1, "host": "mcr-macaddr",
   ...>       "device": "ds/29.0000", "mtime": 1506867918,
   ...>       "type": "relhum",
   ...>       "rh": 56.0})
   ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.relhum?()
   true
  """
  def relhum?(%Reading{} = r) do
    metadata?(r) and r.type === @relhum_t and is_number(r.rh)
  end

  @doc ~S"""
  Is the Reading a switch?

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host": "mcr-macaddr",
    ...>       "device": "ds/29.0000", "mtime": 1506867918,
    ...>        "type": "switch",
    ...>        "states": [{"pio": 0, "state": true},
    ...>                      {"pio": 1, "state": false}],
    ...>        "pio_count": 2})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.switch?()
    true
  """
  def switch?(%Reading{} = r) do
    metadata?(r) and r.type === @switch_t and is_binary(r.device) and is_list(r.states) and
      r.pio_count > 0
  end

  def free_ram_stat?(%Reading{} = r) do
    metadata?(r) and r.type == @mcr_stat_t and is_integer(r.freeram)
  end

  @doc ~S"""
  Is the Reading a cmdack?

   ##Examples:
    iex> json =
    ...>   ~s({"vsn": 1, "host": "mcr-macaddr",
    ...>       "device": "ds/29.0000", "mtime": 1506867918,
    ...>        "type": "switch",
    ...>        "states": [{"pio": 0, "state": true},
    ...>                      {"pio": 1, "state": false}],
    ...>        "pio_count": 2,
    ...>        "cmdack": true, "latency": 10, "refid": "uuid"})
    ...> Mqtt.Reading.decode!(json) |> Mqtt.Reading.cmdack?()
    true
  """
  def cmdack?(%Reading{} = r) do
    switch?(r) and r.cmdack === true and r.latency > 0 and is_binary(r.refid)
  end

  def device(%Reading{} = r), do: r.device
  def states(%Reading{} = r), do: {r.device, r.states}
  def cmdack(%Reading{} = r), do: {r.device, r.states, r.refid, r.latency}

  def as_map(%Reading{} = r), do: Map.from_struct(r)
end
