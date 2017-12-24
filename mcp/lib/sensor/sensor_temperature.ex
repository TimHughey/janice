defmodule SensorTemperature do
@moduledoc """
  The SensorTemperature module provides individual temperature readings for
  a Sensor
"""

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

schema "sensor_temperature" do
  field :tc, :float
  field :tf, :float
  field :ttl_ms, :integer
  belongs_to :sensor, Sensor

  timestamps usec: true
end

end
