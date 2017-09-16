#!/usr/bin/ruby

# Example script using MQTT to access adafruit.io
# - Nicholas Humfrey has an excellent MQTT library, which is very easy to use.

begin
  require 'mqtt'        # gem install mqtt ;  https://github.com/njh/ruby-mqtt
rescue LoadError
  fatal 'The mqtt gem is missing ; try the following command: gem install mqtt'
end

require 'date'
require 'json'

# ---
# Define MQTT config, mostly from the environment, for connecting to Adafruit

begin
  require 'dotenv'      # If a .env file is present, it will be loaded
  Dotenv.load('mqtt.env')           #   into the environment, which is a handy way to do it.
rescue LoadError
  warn 'Warning: dotenv not found - make sure ENV contains proper variables'
end

# Required
ADAFRUIT_USER   = ENV['ADAFRUIT_USER'].freeze
ADAFRUIT_IO_KEY = ENV['ADAFRUIT_IO_KEY'].freeze

# Optional
ADAFRUIT_HOST   = (ENV['ADAFRUIT_HOST'] || 'io.adafruit.com').freeze
ADAFRUIT_PORT   = (ENV['ADAFRUIT_PORT'] || 1883).freeze

ADAFRUIT_FORMAT = ENV['ADAFRUIT_FORMAT'].freeze
CLIENT 					= ENV['CLIENT'].freeze

# ---
# Allow filtering to a specific format

#ADAFRUIT_DOCUMENTED_FORMATS = %w( csv json xml ).freeze
                                      # Adafruit-MQTT doesn't support XML 160619
ADAFRUIT_MQTT_FORMATS       = %w( csv json ).freeze

FORMAT_REGEX_PATTERN        = %r{/(csv|json)$}

FILTER_FORMAT = if ADAFRUIT_FORMAT.nil?
                  nil
                elsif ADAFRUIT_MQTT_FORMATS.include?(ADAFRUIT_FORMAT)
                  "/#{ADAFRUIT_FORMAT}".freeze
                else
                  $stderr.puts("Unsupported format (#{ADAFRUIT_FORMAT})")
                  exit 1
                end

ADAFRUIT_CONNECT_INFO = {
  username: ADAFRUIT_USER,
  password: ADAFRUIT_IO_KEY,
  host:     ADAFRUIT_HOST,
  port:     ADAFRUIT_PORT,
	client_id:	CLIENT,
	clean_session: true 
}.freeze

TOPIC = 'mcr/f/report'
$stderr.puts "Connecting to #{ADAFRUIT_HOST} as #{ADAFRUIT_USER} for #{TOPIC}"

MQTT::Client.connect(ADAFRUIT_CONNECT_INFO).connect do |client|
	client.subscribe(TOPIC => 2)

	last_publish_time = 0;

	while true

		if client.queue_length > 0 	
			feed, data_str = client.get(TOPIC => 2)

			if data_str.include?('{')
				# $stderr.puts "json=#{data_str}"
				datum = JSON.parse(data_str);

				time_diff = Time.new.to_i - datum["mtime"].to_i

				msg = "#{feed}: #{datum["host"]} time_diff=#{time_diff} device=#{datum["device"]} "

				case datum["type"]
					when /temp/
						msg  += "tf=#{datum["tf"]} tc=#{datum["tc"]}"

					when /switch/
						pio = datum["pio"]
						p0 = pio.first
						msg += "pio=#{pio}"
				end

				$stderr.puts msg 
			else
				datum = data_str.split(',')

				id = datum.shift
				mtime = datum.shift

				time_diff = Time.new.to_i - mtime.to_i
				data_timestamp = "#{time_diff}" 
		
				msg = "#{feed}: #{id} #{data_timestamp} "
				msg += datum.map {|x| x.to_f}.keep_if {|x| x > 0.0}.join(" ")
			

				$stderr.puts msg 
			end
		else
			# $stderr.puts "#{TOPIC} queue empty, sleeping...."
			sleep(0.10)
		end
	
		t = Time.new
		time_str = "#{t.to_i} "

		if ((Time.new.to_i - last_publish_time) > 10)
			client.publish('/util/f/mtime', time_str, qos=0)
			client.publish('mcr/f/config', time_str, qos=0)

			last_publish_time = Time.new.to_i
		end
  end
end
# (auto-disconnects when #connect is given a block)

exit 0
