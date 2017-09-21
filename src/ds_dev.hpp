/*
    ds_dev.h - Master Control Dalla Semiconductor Device
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

#ifndef ds_dev_h
#define ds_dev_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "common_dev.hpp"
#include "reading.hpp"

class dsDev : public commonDev {
private:
  static const uint8_t _ds_max_addr_len = 8;
  static const uint8_t _ds_max_id_len = 18;
  static const uint8_t _crc_byte = 7;

  boolean _power = false; // is the device powered?

  static const char *familyDesc(uint8_t family) {
    switch (family) {
    case 0x10:
    case 0x22:
    case 0x28:
      return (const char *)"DS18x20";
      break;

    case 0x29:
      return (const char *)"DS2408";
      break;

    case 0x12:
      return (const char *)"DS2406";
      break;

    default:
      return (const char *)"unknown";
      break;
    }
  };

public:
  dsDev() : commonDev() {
    _power = false;
    _reading = NULL;
  };

  dsDev(byte *addr, boolean power, Reading *reading = NULL)
      : commonDev(reading) {
    // byte   0: 8-bit family code
    // byte 1-6: 48-bit unique serial number
    // byte   7: crc
    memcpy(_addr, addr, _ds_max_addr_len);
    _power = power;

    setDesc(familyDesc(family()));

    memset(_id, 0x00, _max_id_len);
    //                 00000000001111111
    //       byte num: 01234567890123456
    //     exmaple id: ds/28ffa442711604
    // format of name: ds/famil code + 48-bit serial (without the crc)
    //      total len: 18 bytes (id + string terminator)
    sprintf(_id, "ds/%02x%02x%02x%02x%02x%02x%02x",
            _addr[0],                      // byte 0: family code
            _addr[1], _addr[2], _addr[3],  // byte 1-3: serial number
            _addr[4], _addr[5], _addr[6]); // byte 4-6: serial number
  };

  uint8_t family() { return firstAddressByte(); };
  uint8_t crc() { return _addr[_crc_byte]; };
  boolean isPowered() { return _power; };

  static uint8_t *parseId(char *name) {
    static byte addr[_max_addr_len - 1] = {0x00};

    //                 00000000001111111
    //       byte num: 01234567890123456
    // format of name: ds/01020304050607
    //      total len: 18 bytes (id + string terminator)
    if ((name[0] == 'd') && (name[1] == 's') && (name[2] == '/') &&
        (name[_ds_max_id_len - 1] == 0x00)) {
      for (uint8_t i = 3, j = 0; i < _ds_max_addr_len; i = i + 2, j++) {
        char digit[3] = {name[i], name[i + 1], 0x00};
        addr[j] = (byte)(atoi(digit) & 0xFF);
      }
    }

    return addr;
  };

  static bool validROM(uint8_t *rom) { return (rom[0] != 0x00) ? true : false; }
};

#endif // __cplusplus
#endif // ds_dev_h
