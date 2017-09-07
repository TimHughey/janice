defmodule Mcp.I2cSensor.Task do
  @moduledoc :false

  require Logger

  use Timex
  use Bitwise
  alias ElixirALE.I2C
  alias Mcp.{I2cSensor, Switch, Influx, Reading, Duration, Sensor}

  def async_temp_convert(%{sht: sht, hih: hih, am2315: am2315}) do
    start_ts = Timex.now()

    hih_reading = hih_reading(hih)
    sht_reading = sht_reading(sht)
    am2315_reading = am2315_reading(am2315)

    r = %{sht: sht_reading, hih: hih_reading, am2315: am2315_reading}
    scribe(r)

    scribe_us = Timex.diff(Timex.now(), start_ts, :microseconds)
    d = Duration.create("i2c_scribe", scribe_us)
    Influx.post(d)

    {:ok, :temp_convert_done, r}
  end

  def async_reset_am2315 do
    Logger.warn("I2cSensor: async reset of am2315 starting")
    Switch.position(I2cSensor.am2315_pwr_sw(), :false)

    :timer.sleep(I2cSensor.am2315_pwr_wait_ms())

    Switch.position(I2cSensor.am2315_pwr_sw(), :true)
    Logger.warn("I2cSensor: async reset of am2315 complete")

    {:ok, :am2315_reset_done, []}
  end

  defp hih_reading(pid) do
    {eus, {status, {tf, _c, r}}} = :timer.tc(&hih_trigger/1, [pid])

    temp = Reading.create("i2c_hih", "temperature", {eus, {status, tf}})
    rh = Reading.create("i2c_hih", "humidity", {eus, {status, r}})

    %{temperature: temp, humidity: rh}
  end
  defp hih_trigger(:sim), do: simulated_reading_map()
  defp hih_trigger(:nil), do: no_reading_map()
  defp hih_trigger(pid) do
    set_multiplexer(pid, 0)

    I2C.write(pid, <<0x27>>)
    :ok = :timer.sleep(100)

    pid |> I2C.read(4) |> hih_i2c_response()
  end

  defp hih_i2c_response({:error, :i2c_read_failed}) do
    Logger.warn("i2c read of hih failed")
    {:error, {0.0, 0.0, 0.0}}
  end

  defp hih_i2c_response(<<humH, humL, temH, temL>>) do
    status =
      case hih_decode_status(humH) do
        0 -> :ok
        1 -> :error  # :stale
        2 -> :error  # :cmd_mode
        _ -> :error  # :diagnostic
      end

    decode = :binary.decode_unsigned(<<temH, temL>>, :big)
    celsius = decode  / 4 * 1.007e-2 - 40.0
    fahren = celsius_to_fahren(celsius)

    decode = :binary.decode_unsigned(<<Bitwise.band(humH, 0x3f), humL>>, :big)
    rh = decode * 6.10e-3

    {status, {fahren, celsius, rh}}
  end

  defp hih_decode_status(val) do
    (val >>> 0x06) &&& 0x03
  end

  defp sht_reading(pid) do
    {eus, {status, {tf, _c, r}}} = :timer.tc(&sht_trigger/1, [pid])

    temp = Reading.create("i2c_sht", "temperature", {eus, {status, tf}})
    rh = Reading.create("i2c_sht", "humidity", {eus, {status, r}})

    %{temperature: temp, humidity: rh}
  end
  defp sht_trigger(:sim), do: simulated_reading_map()
  defp sht_trigger(:nil), do: no_reading_map()
  defp sht_trigger(pid) do
    set_multiplexer(pid, 0)

    I2C.write(pid, <<0x2C, 0x06>>)
    :ok = :timer.sleep(20)

    pid |> I2C.read(6) |> sht_i2c_response()
  end

  defp sht_i2c_response({:error, :i2c_read_failed}) do
    Logger.warn("i2c read of sht failed")
    {:error, {0.0, 0.0, 0.0}}
  end

  defp sht_i2c_response(<<t_raw::16, tchk::8, rh_raw::16, hchk::8>>) do
    rh = (rh_raw * 100.0) / (1 <<< 16)
    celsius = (t_raw * 175.0) / (1 <<< 16) - 45.0
    fahren = celsius_to_fahren(celsius)

    status =
      if sht_checksum_good?(t_raw, tchk) == :ok and
        sht_checksum_good?(rh_raw, hchk) == :ok do
          :ok
      else
        :error
      end

    {status, {fahren, celsius, rh}}
  end

  defp sht_checksum_good?(value, checksum) do
    case checksum == sht_calc_checksum(value) do
      true  -> :ok
      false -> :error  #:crc_err
    end
  end

  defp sht_calc_checksum(value) do
    crc = 0xFF
    msb = value &&& 0x00FF
    lsb = (value &&& 0xFF00) >>> 8
    Enum.reduce([lsb, msb], crc, &sht_crc_byte/2)
  end

  defp sht_crc_byte(byte, crc) do
    crc = crc ^^^ byte
    Enum.reduce(1..8, crc, &sht_crc_xor/2)
  end

  @poly 0x131
  defp sht_crc_xor(_counter, crc) when band(crc, 0x80) == 0x80 do
     (crc <<< 1) ^^^ @poly
  end

  defp sht_crc_xor(_counter, crc) do
     crc <<< 1
  end

  defp am2315_reading(pid) do
    {eus, {status, {tf, _c, r}}} = :timer.tc(&am2315_trigger/1, [pid])

    temp = Reading.create("i2c_am2315", "temperature", {eus, {status, tf}})
    rh = Reading.create("i2c_am2315", "humidity", {eus, {status, r}})

    %{temperature: temp, humidity: rh}
  end
  defp am2315_trigger(:sim), do: simulated_reading_map()
  defp am2315_trigger(:nil), do: no_reading_map()
  defp am2315_trigger(pid) do
    set_multiplexer(pid, 1)

    # address the device to wake it up, then snooze for a bit
    I2C.write(pid, <<0x00>>)
    :ok = :timer.sleep(I2cSensor.am2315_wait_ms())

    # address the device again to activate a conversion cycle
    cmd = <<0x03, 0x00, 0x04>>
    pid |> I2C.write(cmd)

    :ok = :timer.sleep(10)
    data = pid |> I2C.read(8)

    # power off am2315 to work around hang issue
    # Switch.position(am2315_pwr_sw(), :false)
    # :ok = :timer.sleep(am2315_pwr_wait_ms())
    # Switch.position(am2315_pwr_sw(), :true)

    am2315_i2c_response(data)
  end

  defp am2315_i2c_response({:error, :i2c_read_failed}) do
    Logger.warn("i2c read of am2315 failed")
    {:error, {0.0, 0.0, 0.0}}
  end

  defp am2315_i2c_response(<<cmd_code::8, _bytes::8, rh_raw::16, t_raw::16, _crc::16>>) do
    status =
      case cmd_code do
        0x03 -> :ok
        _    -> :stale
      end

    if status == :stale do
      Logger.warn fn -> "am2315 stale, cmd_code = #{cmd_code}" end
    end

    rh = rh_raw / 10

    # sometimes the device can give a negative temp, mask it out here
    celsius = (t_raw &&& 0x7FFF) / 10
    fahren = celsius_to_fahren(celsius)

    {:ok, {fahren, celsius, rh}}
  end

  defp celsius_to_fahren(celsius) when is_number(celsius) do
    celsius * (9.0/5.0) + 32.0
  end

  defp scribe(rm) when is_map(rm) do
    scribe_reading(rm.hih.temperature)
    scribe_reading(rm.hih.temperature)
    scribe_reading(rm.hih.humidity)
    scribe_reading(rm.sht.temperature)
    scribe_reading(rm.sht.humidity)
    scribe_reading(rm.am2315.temperature)
    scribe_reading(rm.am2315.humidity)
  end

  defp scribe_reading(%Reading{} = r) do
    Reading.if_valid_execute(r, &scribe_reading/2)
  end

  defp scribe_reading(%Reading{} = r, :true) do
    alias Mcp.Sensor

    Sensor.persist(r)
    Influx.post(r)
  end
  defp scribe_reading(%Reading{}, :false), do: nil

  defp simulated_reading_map do
    celsius = :rand.uniform(50) / 1  # divide by 1 converts to float
    fahren = celsius_to_fahren(celsius)
    rh = :rand.uniform(99) / 1

    {:ok, {fahren, celsius, rh}}
  end

  defp no_reading_map, do: {:error, {0.0, 0.0, 0}}

  defp set_multiplexer(pid, channel)
  when channel >= 0 and channel < 8 do
    m = Application.get_env(:mcp, :genservers)

    if m[Elixir.Mcp.I2cSensor][:i2c_use_multiplexer] do
      I2C.write_device(pid, 0x70, <<(1 <<< channel)>>)
    end
  end
end
