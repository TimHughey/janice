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

#include "common_dev.hpp"
#include "mcr_util.hpp"
#include "reading.hpp"

class i2cDev : public commonDev {
private:
  static const uint8_t _i2c_max_addr_len = 1;
  static const uint8_t _i2c_max_id_len = 30;
  static const uint8_t _i2c_addr_byte = 0;
  boolean _use_multiplexer; // is the multiplexer is needed to reach device
  uint8_t _bus;             // if using multiplexer then this is the bus number
                            // where the device is hosted

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

public:
  i2cDev() : commonDev() {
    _use_multiplexer = false;
    _bus = 0;
  };

  i2cDev(uint8_t addr, boolean use_multiplexer = false, uint8_t bus = 0,
         Reading *reading = NULL)
      : commonDev(reading) {
    _addr[_i2c_addr_byte] = addr;
    _use_multiplexer = use_multiplexer;
    _bus = bus;

    setDesc(i2cDevDesc(firstAddressByte()));

    memset(_id, 0x00, _max_id_len);
    //                 0000000000111111111122222222223
    //       byte num: 0123456789012345678901234567890
    //      example id: i2c/f8f005f73b53.04.am2315
    //    format of id: i2c/mac_address/bus/desc
    //        max len: 30 bytes (id + string terminator)
    sprintf(_id, "i2c/%s.%02x.%s", mcrUtil::macAddress(), this->bus(), desc());
  };

  uint8_t devAddr() { return commonDev::addr()[_i2c_addr_byte]; };
  boolean useMultiplexer() { return _use_multiplexer; };
  uint8_t bus() { return _bus; };
};

#endif // __cplusplus
#endif // i2c_dev_h
