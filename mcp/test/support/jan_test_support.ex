defmodule JanTest do
  @moduledoc """

  """

  def base_ext(name, num),
    do: %{
      host: host(name, num),
      name: name(name, num),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
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

  # SENSORS

  def relhum_ext(num) do
    base = base_ext("sensor", num)

    sensor = %{
      type: "relhum",
      device: device("sensor", num),
      rh: random_float(),
      tc: random_float()
    }

    Map.merge(base, sensor)
  end

  def relhum_dev(n), do: device("sensor", n + 50)

  def relhum_ext_msg(n) do
    # all relative humidity senors start at 50 for test purposes
    # also avoids conflicts with temperature sensors
    n = n + 50
    relhum_ext(n) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end

  def relhum_name(n), do: name("sensor", n + 50)

  def sen_dev(n), do: device("sensor", n)
  def sen_host(n), do: host("sensor", n)
  def sen_name(n), do: name("sensor", n)

  def temp_ext(num, opts \\ []) do
    tc = Keyword.get(opts, :tc, random_float())
    base = base_ext("sensor", num)

    sensor = %{
      type: "temp",
      device: device("sensor", num),
      tc: tc
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n, opts \\ []) do
    temp_ext(n, opts) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end
end
