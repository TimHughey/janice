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
require 'securerandom'

# ---
# Define MQTT config, mostly from the environment

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

def send_time_sync(client) 
	t = Time.new
	time_str = "#{t.to_i} "

	time_sync_hash = {
		:version => "1", :cmd => "time.sync", :mtime => "#{time_str}", :key => "0xAA" }

	time_sync_json = JSON.generate(time_sync_hash)

	client.publish('mcr/f/command', time_sync_json, qos=0)
end


def human_ms(msec)
	unit = "ms"
  val = msec.round(2)

	if msec > 1000
		unit = "s"
		val = msec / 1000
		val = val.round(2)
	end

	return "#{val}#{unit}"
end

def human_us(usec)
	unit = "us"
  val = usec

	if usec > 1000
		unit = "ms"
		val = usec / 1000
		val = val.round(2)
	end

	return "#{val}#{unit}"
end
	


MQTT::Client.connect(ADAFRUIT_CONNECT_INFO).connect do |client|
	log = File.open("/tmp/merc.log", "a+")

	client.subscribe(TOPIC => 2)

	cmd_tracker = Hash.new
	last_publish_time = Time.new;
	last_heartbeat_time = Time.new
	last_led_flash = Time.new

	led_state = true
	while true

		if client.queue_length > 0 	
			feed, data_str = client.get(TOPIC => 2)

			if data_str.include?('{')
				# $stderr.puts "json=#{data_str}"
				datum = JSON.parse(data_str);

				if (datum.has_key?("mtime"))
					msg_time = Time.at(datum["mtime"])
				else
					msg_time = Time.now()
					latency = 0
				end

				# msg1 = "#{msg_time} host=#{datum["host"]} "
				msg1 = "#{msg_time}  "
				# msg2 = " " * (feed.length - 1) 
				msg2 = " "

				if datum.has_key?("startup")
					send_time_sync(client)
					last_publish_time = Time.new.to_i
					msg2 += "startup=#{datum["startup"]}"
				end

				if datum.has_key?("device")
					time_diff = Time.new.to_i - datum["mtime"].to_i

					# msg1 += "device=#{datum["device"]} type=#{datum["type"]} time_diff=#{time_diff}" 
					msg1 += "#{datum["device"]} #{datum["type"]} " 

					if (datum.has_key?("cmdack"))
						msg1 += "cmdack latency=#{human_us(datum["latency"])} ";

						# handle the returned UUID (cid) if it exists
						if datum.has_key?("cid")
							cid = datum["cid"]
							if cmd_tracker.has_key?(cid)
								sent_mtime = cmd_tracker[cid]
								cmd_tracker.delete(cid)
								rt_latency = (Time.now - sent_mtime) * 1000
								msg1 += "rt_latency=#{human_ms(rt_latency)}"
							end
						end
					end

					case datum["type"]
						when /temp/
							msg2 += "tf=#{datum["tf"]} tc=#{datum["tc"]}"

						when /switch/
							pio = datum["pio"]
							p0 = pio.first
							msg2 += "pio=#{pio}"

						when /relh/
							msg2 += "tf=#{datum["tf"]} tc=#{datum["tc"]} rh=#{datum["rh"]}"
					end
				end

				case datum['type']
					when /switch/
						if (datum.has_key?("cmdack"))
							$stderr.puts msg1
							$stderr.puts "   #{msg2}"
							$stderr.puts " "
		
							log.puts msg1
							log.puts "   #{msg2}"
							log.puts " "
							log.fsync

						end
				end

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
			sleep(0.01)
		end
	
		if ((Time.new.to_i - last_publish_time.to_i) > 10)
			send_time_sync(client)
			last_publish_time = Time.new.to_i
		end

		heartbeat_time = Time.new
		if ((heartbeat_time.to_i - last_heartbeat_time.to_i) > 10)
			heartbeat_hash = {
				:version => "1", :cmd => "heartbeat", :mtime => "#{heartbeat_time.to_i}", :key => "0xAA",
				:master => ADAFRUIT_HOST }

			heartbeat_json = JSON.generate(heartbeat_hash)

			client.publish('mcr/f/command', heartbeat_json, qos=0)

			last_heartbeat_time = heartbeat_time;
		end

		led = "ds/291d1823000000"
	#	switch = "ds/124c8421000000"
		buzzer = "ds/12128521000000"
		sysX = "ds/12838421000000"
		sysY = "ds/12398521000000"
		sysZ = "ds/124c8421000000"
		pio = 0

		devs = [ led, sysZ, sysX]
		states = [true, false]

		led_flash = Time.new
		if ((led_flash.to_i - last_led_flash.to_i) >= 3)
		
			#hash1 = {
			#	:version => "1", :cmd => "set.switch", :mtime => "#{led_flash.to_i}", :key => "0xAA",
			#	:switch => buzzer, :pio => ["#{pio}" => true], :pio_count => 1 }

			for d in devs
				for s in states
					cid = SecureRandom.uuid
					hash = {
						:version => "1", :cmd => "set.switch", :mtime => "#{led_flash.to_i}", :key => "0xAA",
						:switch => d, :pio => ["#{pio}" => s], :pio_count => 1, :cid => cid }

					json = JSON.generate(hash)
					cmd_tracker[cid] = Time.now
					client.publish('mcr/f/command', json, qos=0)
			#		sleep(0.05)
				end
			end


			led_state = not(led_state)
			last_led_flash = led_flash

		end
  end
end


# (auto-disconnects when #connect is given a block)
exit 0
