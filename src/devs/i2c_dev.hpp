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

#ifndef i2c_dev_h
#define i2c_dev_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "../misc/mcr_util.hpp"
#include "../readings/reading.hpp"
#include "mcr_dev.hpp"

typedef class i2cDev i2cDev_t;

class i2cDev : public mcrDev {
public:
  static const char *i2cDevDesc(uint8_t addr) {
    switch (addr) {
    case 0x5C:
      return (const char *)"am2315";
      break;

    case 0x44:
      return (const char *)"sht31";
      break;

    default:
      return (const char *)"unknown";
      break;
    }
  }

private:
  static const uint8_t _i2c_max_addr_len = 1;
  static const uint8_t _i2c_max_id_len = 30;
  static const uint8_t _i2c_addr_byte = 0;
  boolean _use_multiplexer; // is the multiplexer is needed to reach device
  uint8_t _bus;             // if using multiplexer then this is the bus number
                            // where the device is hoste
public:
  i2cDev() {
    _use_multiplexer = false;
    _bus = 0;
  }

  // construct a new i2cDev with a known address and compute the id
  i2cDev(mcrDevAddr_t &addr, bool use_multiplexer = false, uint8_t bus = 0)
      : mcrDev(addr) {
    _use_multiplexer = use_multiplexer;
    _bus = bus;
    char buff[_id_len] = {0x00};

    setDesc(i2cDevDesc(firstAddressByte()));

    //                 0000000000111111111122222222223
    //       byte num: 0123456789012345678901234567890
    //      example id: i2c/f8f005f73b53.04.am2315
    //    format of id: i2c/mac_address/bus/desc
    //        max len: 30 bytes (id + string terminator)
    sprintf(buff, "i2c/%s.%02x.%s", mcrUtil::macAddress(), this->bus(), desc());
    setID(buff);
  };

  uint8_t devAddr() { return firstAddressByte(); };
  boolean useMultiplexer() { return _use_multiplexer; };
  uint8_t bus() { return _bus; };

  // info / debugg functions
  void printReadMS(const char *func, uint8_t indent = 2) {
    mcrUtil::printDateTime(func);
    Serial.print(desc());
    Serial.print(" ");
    Serial.print((char *)id());
    Serial.print(" read took ");
    Serial.print(readMS());
    Serial.println("ms");
  }
};

#endif // __cplusplus
#endif // i2c_dev_h
