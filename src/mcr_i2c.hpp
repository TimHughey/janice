/*
    mcr_i2c.h - Master Control Remote I2C
    Copyright (C) 2017  Tim Hughey

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    https://www.wisslanding.com
*/

#ifndef mcr_i2c_h
#define mcr_i2c_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <Wire.h>

#include "i2c_dev.hpp"
#include "mcr_engine.hpp"
#include "mcr_mqtt.hpp"
#include "mcr_util.hpp"
#include "reading.hpp"

#define mcr_i2c_version_1 1

// Set the version of MCP Remote
#ifndef mcr_i2c_version
#define mcr_i2c_version mcr_i2c_version_1
#endif

#define I2C_PWR_PIN 12
#define MAX_DEV_NAME 20

class mcrI2C : public mcrEngine {

private:
  i2cDev **known_devs;
  boolean use_multiplexer = false;

public:
  mcrI2C(mcrMQTT *mqtt);
  boolean init();

private:
  i2cDev _search_devs[2] = {i2cDev(0x5C), i2cDev(0x44)};
  i2cDev *search_devs() { return _search_devs; };
  inline uint8_t search_devs_count() {
    return sizeof(_search_devs) / sizeof(i2cDev);
  };

  i2cDev *addDevice(byte addr, bool use_multiplexer, byte bus) {
    i2cDev *dev = NULL;

    if (devCount() < maxDevices()) {
      dev = new i2cDev(addr, use_multiplexer, bus);
      known_devs[devCount()] = dev;
      mcrEngine::addDevice();
    } else {
      Serial.print("    ");
      Serial.print(__PRETTY_FUNCTION__);
      Serial.println(" attempt to exceed maximum devices");
    }

    return dev;
  };

  boolean discover();
  boolean report();

  // specific methods to read devices
  boolean readAM2315(i2cDev *dev, Reading **reading);
  boolean readSHT31(i2cDev *dev, Reading **reading);

  // utility methods
  uint8_t crcSHT31(const uint8_t *data, uint8_t len);
  boolean detectDev(uint8_t addr, boolean use_multiplexer = false,
                    uint8_t bus = 0x00);

  void clearKnownDevices() {
    for (uint8_t i = 0; i < maxDevices(); i++) {
      if (known_devs[i] != NULL) {
        delete known_devs[i];
        known_devs[i] = NULL;
      }
    }

    mcrEngine::clearKnownDevices();
  }
};

#endif // __cplusplus
#endif // mcr_i2c_h
