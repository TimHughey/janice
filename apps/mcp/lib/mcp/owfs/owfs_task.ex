defmodule Mcp.Owfs.Task do
  @moduledoc :false

  require Logger
  alias Mcp.{Owfs, Owfs.Util, Reading, Duration, Influx}

  @simultaneous_temp "simultaneous/temperature"
  @true_string "1"

  def async_temp_convert do
    bus_list = Util.bus_list()
    c = Enum.count(bus_list)

    for bus <- Util.bus_list() do
      parts = [Util.owfs_path(), bus, @simultaneous_temp]
      f = Path.join(parts)

      case File.exists?(f) do
        :true  -> File.write(f, @true_string)
        :false -> :ok
      end
    end

    :timer.sleep(750)

    {eus, _} = :timer.tc(&scribe/0, [])

    d = Duration.create("owfs_scribe", eus)

    Influx.post(d)

    {:ok, :temp_convert_done, c}
  end

  defp scribe do
    scribe(Owfs.Sensor.all())
  end
  defp scribe([]), do: []
  defp scribe(names) when is_list(names) do
    # pluck the first name from the list and scribe all readings
    scribe(hd(names))

    # progress through the rest of the list
    scribe(tl(names))
  end
  defp scribe(name) when is_binary(name) do
    scribe_sensor(name, Owfs.Sensor.available_readings(name))
  end

  defp scribe_sensor(name, []) when is_binary(name), do: []
  defp scribe_sensor(name, kinds) when is_binary(name) and is_list(kinds) do
    scribe_sensor(name, hd(kinds))
    scribe_sensor(name, tl(kinds))
  end

  defp scribe_sensor(name, kind) when is_binary(name) and is_binary(kind) do
    name |> Owfs.Sensor.reading(kind) |> scribe_sensor()
  end

  # callback from Reading when the Reading is valid
  defp scribe_sensor(%Reading{} = r, :true) do
    Mcp.Sensor.persist(r)
#    Mcp.Sensor.persist(Reading.name(r), Reading.kind(r),
#      Reading.val(r), Reading.read_at(r))

    Influx.post(r)
  end

  # callback from Reading when the Reading is not valid
  defp scribe_sensor(%Reading{}, :false), do: nil

  defp scribe_sensor(%Reading{} = r) do
    # Reading will callback the passed function with :true or :false
    # indicating if the Reading is valid or not
    Reading.if_valid_execute(r, &scribe_sensor/2)
  end

end
