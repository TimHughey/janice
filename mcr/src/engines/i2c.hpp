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

#include "../devs/addr.hpp"
#include "../devs/i2c.hpp"
#include "../devs/id.hpp"
#include "../include/readings.hpp"
#include "../misc/util.hpp"
#include "../protocols/mqtt.hpp"
#include "engine.hpp"

#define mcr_i2c_version_1 1

// Set the version of MCP Remote
#ifndef mcr_i2c_version
#define mcr_i2c_version mcr_i2c_version_1
#endif

#define I2C_PWR_PIN 12
#define MAX_DEV_NAME 20

typedef class mcrI2c mcrI2c_t;
class mcrI2c : public mcrEngine {
private:
  static const uint8_t _max_buses = 8;
  bool _use_multiplexer = false;

public:
  mcrI2c(mcrMQTT_t *mqtt);
  bool init();

private:
  mcrDevAddr_t _search_addrs[2] = {mcrDevAddr(0x5C), mcrDevAddr(0x44)};
  mcrDevAddr_t *search_addrs() { return _search_addrs; };
  inline uint8_t search_addrs_count() {
    return sizeof(_search_addrs) / sizeof(mcrDevAddr_t);
  };

  bool discover();
  bool report();

  // specific methods to read devices
  bool readAM2315(i2cDev_t *dev, humidityReading_t **reading);
  bool readSHT31(i2cDev_t *dev, humidityReading_t **reading);

  // utility methods
  uint8_t crcSHT31(const uint8_t *data, uint8_t len);
  bool detectDev(mcrDevAddr_t &addr, boolean use_multiplexer = false,
                 uint8_t bus = 0x00);

  bool detectMultiplexer();
  uint8_t maxBuses();
  bool useMultiplexer();
  void selectBus(uint8_t bus);
  void printUnhandledDev(const char *func, i2cDev_t *dev);
};

#endif // __cplusplus
#endif // mcr_i2c_h
