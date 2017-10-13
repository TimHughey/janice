require 'date'
require 'json'
require 'securerandom'
require 'socket'

class CmdTracker
  # tracker is a hash of the ref ids (UUID) and the time the cmd was sent
  def initialize
    @tracker = {}
  end

  def new_ref_id
    SecureRandom.UUID
  end

  def track
    ref_id = new_ref_id
    track(ref_id)
  end

  def track(ref_id)
    @tracker[ref_id] = Time.now
  end

  # takes a ref_id -- if ref_id is known then returns the roundtrip latency
  # if not known returns 0
  def untrack(ref_id, _logger = false, _console = false, _indent = 0)
    rt_latency = 0 # the measured rount trip latency

    if @tracker.key?(ref_id)
      sent_mtime = @tracker[ref_id]
      @tracker.delete(ref_id)
      rt_latency = (Time.now - sent_mtime) * 1000

      if _logger || _console
        msg = ' ' * _indent
        msg += "rt_latency=#{rt_latency}"

        if _logger
          _logger.write(msg)
          _logger.fsync
        end

        $stderr.write(msg) if _console
      end
    end
    rt_latency
  end
end
