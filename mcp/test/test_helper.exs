Mixtank.delete_all(:dangerous)
Switch.delete_all(:dangerous)
Sensor.delete_all(:dangerous)
Remote.delete_all(:dangerous)

ExUnit.configure(exclude: [ota: true])
ExUnit.start()
