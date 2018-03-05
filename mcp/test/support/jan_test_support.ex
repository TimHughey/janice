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

  def sen_dev(n), do: device("sensor", n)
  def sen_host(n), do: host("sensor", n)
  def sen_name(n), do: name("sensor", n)

  def temp_ext(num) do
    base = base_ext("sensor", num)
    tc = random_float()
    tf = tc * (9.0 / 5.0) + 32.0

    sensor = %{
      type: "temp",
      device: device("sensor", num),
      tc: tc,
      tf: tf
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n \\ 0) do
    temp_ext(n) |> Jason.encode!() |> Mqtt.InboundMessage.process(async: false)
  end
end
