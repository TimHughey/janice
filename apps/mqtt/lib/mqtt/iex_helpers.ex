defmodule Mqtt.Client.IExHelpers do
@moduledoc """
"""

alias Mqtt.Client
def mqtt_start do
  Client.connect()
  Client.report_subscribe()
end

end
