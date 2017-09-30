defmodule Mercurial.MQTTClient.IExHelpers do
  def connect do
    Mercurial.MQTTClient.connect()
  end

  def subscribe do
    opts = [topics: ["mqtt/f/feather"], qoses: [0]]
    Mercurial.MQTTClient.subscribe(opts)
  end
    
end
