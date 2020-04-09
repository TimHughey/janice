defmodule Mqtt.SetPulseWidth do
  @moduledoc false

  require Logger

  def create_cmd(
        %PulseWidth{device: device},
        %PulseWidthCmd{refid: refid},
        opts
      )
      when is_list(opts) do
    import Janice.TimeSupport, only: [unix_now: 1]

    %{
      cmd: "pwm",
      mtime: unix_now(:second),
      device: device,
      refid: refid,
      ack: Keyword.get(opts, :ack, true),
      duty: Keyword.get(opts, :duty, 0),
      fade_ms: Keyword.get(opts, :fade_ms, 30)
    }
  end
end
