# Janice

As of 2017-12-20

Janice provides system for collecting sensor data, controlling switches
and making making data available via a web interface and through a timeseries
database.

## Remote Devices
- Data is collected by [Adafruit Feather M0](https://www.adafruit.com/product/3010)
devices flashed with [Master Control Remote](mcr/README.md)
- Collected data is published to a MQTT feed via wifi
  - Payload is JSON
- Sensors and switches currently supported
  - Maxim Integrated Devices
    - [DS18S20](https://datasheets.maximintegrated.com/en/ds/DS18S20.pdf) Temperature Sensor
    - [DS2406](https://www.maximintegrated.com/en/products/digital/memory-products/DS2406.html) Two-Channel Switch
    - [DS2408](https://www.maximintegrated.com/en/products/digital/memory-products/DS2408.html) Eight-Channel Switch
  - i2c Devices
    - [AM2315](https://www.adafruit.com/product/1293) Temperature / Humidity Sensor
    - [Sensiron SHT-31](https://www.adafruit.com/product/1293) Temperature / Humidity Sensor
    - [TCA9548A 1-to-8 I2C multiplexer](https://learn.adafruit.com/adafruit-tca9548a-1-to-8-i2c-multiplexer-breakout/overview)
- Commands are received to change the state of attached switches
  - Return messages are sent to confirm the switch state was changed
- Time sync messages are received to set the local time on the device
- Records various metrics related to reading sensors and setting switches
  - Metrics are sent via MQTT to the central server for operational reporting and monitoring

## Central Server
- Data received via the MQTT feed is processed by the [Master Control Program](mcp/README.md)
- Sensor and switch data are persisted to [Postgres](https://www.postgresql.org) and [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) (for operational stats)
- Switch states changed centrally are published to the remote devices
  - Switch commands are tracked and acks from remote devices correlated

## Controlling Systems
- Ability to control a Mixtank
- Dutycycles  *Coming Soon*
- Chambers *Coming Soon*

## Web and API
- Built with Elixir Phoenix
- Uses Bootstrap 4 for styling and layout
- Fully integrated [Ueberauth](https://github.com/ueberauth/ueberauth) and [Guardian](https://github.com/ueberauth/guardian)
  - GitHub auth in production
  - Simple identity (user/password) in dev
  - Protection on web and api
- MCP details page (for authorized users only) to view
  - Device Aliases
  - Switches
  - Sensors

### Elixir Hex Packages Leveraged
```elixir
def deps do
  [{:timex, "~> 3.0"},
   {:poison, "~> 3.1", override: true},
   {:instream, "~> 0.16"},
   {:hackney, "~> 1.1"},
   {:poolboy, "~> 1.5"},
   {:httpoison, "~> 0.12"},
   {:postgrex, "~> 0.13"},
   {:ecto, "~> 2.1"},
   {:timex_ecto, "~> 3.1"},
   {:uuid, "~> 1.1"},
   {:hulaaki, "~> 0.1.0"},
   {:phoenix, "~> 1.3.0"},
   {:phoenix_pubsub, "~> 1.0"},
   {:phoenix_ecto, "~> 3.2"},
   {:phoenix_html, "~> 2.10"},
   {:phoenix_live_reload, "~> 1.0", only: :dev},
   {:gettext, "~> 0.11"},
   {:cowboy, "~> 1.0"},
   {:guardian, "~> 1.0"},
   {:ueberauth, "~> 0.4"},
   {:ueberauth_github, "~> 0.4"},
   {:ueberauth_identity, "~> 0.2"},
   {:distillery, "~> 1.0"},
   {:credo, "> 0.0.0", only: [:dev, :test]}]
end
```
