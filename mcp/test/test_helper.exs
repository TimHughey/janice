#
# before running tests delete everything in the database
#
[
  Thermostat,
  MessageSave,
  Dutycycle,
  SwitchGroup,
  Switch,
  Switch.Alias,
  Switch.Device,
  PulseWidth,
  Sensor,
  Remote
]
|> JanTest.delete_all()

#
# ExUnit.configure(
#   exclude: [ota: true, mixtank: true, dutycycle: true],
#   include: [thermostat: true]
# )

ExUnit.start()
