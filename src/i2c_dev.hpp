/*
    mcpr_i2c.h - Master Control Remote I2C
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

#include "mcr_util.hpp"
#include "reading.hpp"

class i2cDev {
private:
  byte _addr;
  boolean _use_multiplexer;
  byte _bus;

  static const uint8_t max_id = 30;
  char _id[max_id] = {0x00};

  char _desc[15];
  Reading *_reading = NULL;

public:
  i2cDev(byte addr, boolean use_multiplexer = false, uint8_t bus = 0) {
    _addr = addr;
    _use_multiplexer = use_multiplexer;
    _bus = bus;

    switch (addr) {
    case 0x5C:
      strcpy(_desc, "am2315");
      break;

    case 0x44:
      strcpy(_desc, "sht31");
      break;

    default:
      strcpy(_desc, "unknown");
      break;
    }

    memset(_id, 0x00, max_id);
    //                 0000000000111111111122222222223
    //       byte num: 0123456789012345678901234567890
    // format of name: i2c/f8f005f73b53.04.am2315
    //        max len: 30 bytes (id + string terminator)
    sprintf(_id, "i2c/%s.%02x.%s", mcrUtil::macAddress(), _bus, desc());
  };

  // destructor necessary because of possibly embedded reading
  ~i2cDev() {
    if (_reading != NULL)
      delete _reading;
  };

  void setReading(Reading *reading) {
    if (_reading != NULL)
      delete _reading;
    _reading = reading;
  };

  byte addr() { return _addr; };
  char *desc() { return _desc; };

  boolean useMultiplexer() { return _use_multiplexer; };
  uint8_t bus() { return _bus; };

  const char *id() { return _id; };
};

#endif // __cplusplus
#endif // i2c_dev_h
