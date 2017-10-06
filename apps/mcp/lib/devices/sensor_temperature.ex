defmodule Mcp.SensorTemperature do
@moduledoc """
  The SensorTemperature module provides individual temperature readings for
  a Sensor
"""

alias __MODULE__

require Logger
use Timex
use Timex.Ecto.Timestamps
use Ecto.Schema

import Application, only: [get_env: 2]
import UUID, only: [uuid1: 0]
import Ecto.Changeset, only: [change: 2]

import Mcp.Repo, only: [query: 1]

#import Mqtt.Client, only: [publish_switch_cmd: 1]

schema "sensor_temperature" do
  field :tc, :float
  field :tf, :float
  field :ttl_ms, :integer
  belongs_to :sensor, Mcp.Switch

  timestamps usec: true
end

end
