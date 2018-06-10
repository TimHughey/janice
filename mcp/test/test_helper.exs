Thermostat.delete_all(:dangerous)
Mixtank.delete_all(:dangerous)
Dutycycle.delete_all(:dangerous)
Switch.delete_all(:dangerous)
Sensor.delete_all(:dangerous)
Remote.delete_all(:dangerous)

# ExUnit.configure(exclude: [ota: true, mixtank: true, dutycycle: true])
ExUnit.configure(
  exclude: [ota: true, mixtank: true, dutycycle: true],
  include: [thermostat: true]
)

ExUnit.start()
