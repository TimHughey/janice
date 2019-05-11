defmodule JanTest do
  @moduledoc false

  alias Janice.TimeSupport

  def base_ext(name, num),
    do: %{
      host: host(name, num),
      name: name(name, num),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false
    }

  def device(name, n), do: "ds/#{name}#{num_str(n)}"
  def host(name, n), do: "mcr.#{name}#{num_str(n)}"

  def mt_host(n), do: host("mixtank", n)
  def mt_name(n), do: name("mixtank", n)

  def name(prefix, n), do: "#{prefix}#{num_str(n)}"
  def num_str(n), do: String.pad_leading(Integer.to_string(n), 3, "0")
  def preferred_vsn, do: "b4edefc"

  def random_float do
    a = :rand.uniform(25)
    b = :rand.uniform(100)

    a + b * 0.1
  end

  ####
  #### SENSORS
  ####

  def relhum_ext(num) do
    base = base_ext("sensor", num)

    sensor = %{
      type: "relhum",
      device: device("relhum", num),
      rh: random_float(),
      tc: random_float(),
      tf: random_float()
    }

    Map.merge(base, sensor)
  end

  def relhum_dev(n), do: device("relhum", n + 50)

  def relhum_ext_msg(n) do
    # all relative humidity senors start at 50 for test purposes
    # also avoids conflicts with temperature sensors
    n = n + 50
    relhum_ext(n) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end

  def relhum_name(n), do: name("relhum", n + 50)

  def sen_dev(n), do: device("sensor", n)
  def sen_host(n), do: host("sensor", n)
  def sen_name(n), do: name("sensor", n)

  def soil_ext(num, opts \\ []) do
    tc = Keyword.get(opts, :tc, random_float())
    cap = Keyword.get(opts, :cap, :rand.uniform(600))
    base = base_ext("sensor", num)

    sensor = %{
      type: "soil",
      device: device("sensor", num),
      tc: tc,
      tf: tc,
      cap: cap
    }

    Map.merge(base, sensor)
  end

  def soil_ext_msg(n, opts \\ []) do
    soil_ext(n, opts) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end

  def temp_ext(num, opts \\ []) do
    tc = Keyword.get(opts, :tc, random_float())
    base = base_ext("sensor", num)

    sensor = %{
      type: "temp",
      device: device("sensor", num),
      tc: tc,
      tf: tc
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n, opts \\ []) do
    temp_ext(n, opts) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end

  def create_temp_sensor(sub, name, num, opts \\ []) do
    tc = opts[:tc] || random_float()
    base = base_ext(sub, num)

    sensor = %{type: "temp", device: name, tc: tc}

    Map.merge(base, sensor) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end

  ####
  #### SWITCHES
  ####

  def create_switch(num, num_pios, pos) when is_integer(num) do
    switch_ext("switch", num, num_pios, pos) |> Switch.external_update()
  end

  def create_switch(sub, name, num, num_pios, pos) when is_binary(name) do
    %{
      host: sub,
      name: name,
      hw: "esp32",
      device: device(sub, num),
      pio_count: num_pios,
      states: pios(num_pios, pos),
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false
    }
    |> Switch.external_update()
  end

  def device_pio(num, pio), do: device("switch", num) <> ":#{pio}"
  def pios(num, pos), do: for(n <- 0..(num - 1), do: %{pio: n, state: pos})

  def switch_ext(name, num, num_pios, pos),
    do: %{
      host: host(name, num),
      name: name("switch", num),
      hw: "esp32",
      device: device(name, num),
      pio_count: num_pios,
      states: pios(num_pios, pos),
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false
    }
end
