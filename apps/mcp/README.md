
# Master Control Program (MCP)

Hobby project intended to create a master control program for automating operations of Wiss Landing (my house).  After decades of imperative programming this was my excuse to jump head first into functional programming.  Now I'm in love with functional programming and Elixir. Most days when writing functional code I ask myself, "Where has this been all my (programming) life)?"

**Disclaimer**

This code in no way perfect and there are sections where I've cheated or wrote bad code.  Yes, that is certainly the case.  If someone happens to use this code and finds such offsenses please let me know.

### Implemented Thus Far ###
  #### Reading and storing sensor data ####
  1. Maxim/Dallas Semiconductor devices via [OWFS](http://www.owfs.org)
  2. I2C devices (temperature and humidity)
  3. Stores readings in [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb) (a timeseries database)

  #### Controlling Relays ####
  1. Maxim/Dallas Semiconductor switches activating relays

  #### Automations ####
  1. Reef water mix
      - automates some parts of the repeative mixing of reef water
      - warms water to match reef tank to prevent temperature swing during water change
      - periodically runs air pump and water pump to stir water
      - supports different modes
        1. `minimal` maintains water temperature with minimal stirring
        2. `fill` activates RODI water valve to fill mix tank
            - limits fill during the day (so rest of house has RODI)
            - maximizes fill overnight
        3. `mix` circulates water and adds air while mixing in salt
        4. `change` runs pump for performing water change (no air added)
  2. Dutycycle control
      - controls a switch (and ultimately a device) based on configured idle and run durations

  - **[deprecated]** Controls relays and reads A/D values of a National Control Devices 8-channel relay board via USB


 Future implementations will include:
  - Drip irrigation control
  - Agriculture environment control
