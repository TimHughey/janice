defmodule Fact.Sensor do
  @moduledoc false

  # alias Fact.Celsius
  # import(Fact.Influx, only: [write: 2])
  #
  # alias Janice.TimeSupport

  #   %{
  #   points: [
  #     %{
  #       database: "my_database", # Can be omitted, so default is used.
  #       measurement: "my_measurement",
  #       fields: %{answer: 42, value: 1},
  #       tags: %{foo: "bar"},
  #       timestamp: 1439587926000000000 # Nanosecond unix timestamp with
  #                                        default precision, can be omitted.
  #     },
  #     # more points possible ...
  #   ],
  #   database: "my_database", # Can be omitted, so default is used.
  # }
  # |> MyApp.MyConnection.write()

  def record, do: false
end
