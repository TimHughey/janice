# Mercurial

**TODO: Add description**

---
### Adafruit Feather M0 Maxim One-Wire Bus Master
#### High-Level Design Concepts

  1. Connect / reconnect to WiFi network
  2. Connect / reconnect to MQTT broker
  3. Maintain date / time based on MQTT time feed
  4. Runtime parameters adjusted dynamically
    1. Receive configuration changes via MQTT
  5. Use JSON for the data layer
  6. Support Maxim One-Wire devices
    1. DS18S20
    2. DS2438
    3. Switches
  7. Support I2C humidity sensor
  8. Support soil moisture sensor
  9. Maintain a list of known devices
    1. Update list at a regular interval
    2. Provide mechanism to check elapsed millis since last update
    3. Record powered status of each device
    4. Publish known devices via MQTT
    5. Track elapsed duration of device discovery
      1. Report duration via MQTT
  10. Perform temperature conversions
    1. Use simulatenous temperature conversions when possible
    2. Store temperature measurements and timestamp of when measured
    3. Publish temperature measurements via MQTT
  11. Read Switch positions
  12. Write Switch positions
  13. 
