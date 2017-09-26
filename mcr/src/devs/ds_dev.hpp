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

#include <OneWire.h>

#include "../misc/mcr_util.hpp"
#include "../readings/reading.hpp"
#include "mcr_dev.hpp"

typedef class dsDev dsDev_t;

class dsDev : public mcrDev {
private:
  // static const uint8_t _addr_len = 8;
  // static const uint8_t _id_len = 18;
  static const uint8_t _ds_max_addr_len = 8;
  static const uint8_t _family_byte = 0;
  static const uint8_t _crc_byte = 7;

  static const uint8_t _family_DS2408 = 0x29;
  static const uint8_t _family_DS2406 = 0x12;

  bool _power = false; // is the device powered?

  static const char *familyDesc(uint8_t family) {
    switch (family) {
    case 0x10:
    case 0x22:
    case 0x28:
      // return (const char *)"DS18x20";
      return (const char *)"ds1820";
      break;

    case 0x29:
      return (const char *)"ds2408";
      break;

    case 0x12:
      return (const char *)"ds2406";
      break;

    default:
      return (const char *)"dsUNDEF";
      break;
    }
  };

  const char *familyDesc() { return familyDesc(family()); }

public:
  dsDev() { _power = false; };

  dsDev(mcrDevAddr_t &addr, bool power = false) : mcrDev(addr) {
    char buff[_ds_max_addr_len] = {0x00};
    // byte   0: 8-bit family code
    // byte 1-6: 48-bit unique serial number
    // byte   7: crc
    _power = power;

    setDesc(familyDesc(family()));

    //                 00000000001111111
    //       byte num: 01234567890123456
    //     exmaple id: ds/28ffa442711604
    // format of name: ds/famil code + 48-bit serial (without the crc)
    //      total len: 18 bytes (id + string terminator)
    sprintf(buff, "ds/%02x%02x%02x%02x%02x%02x%02x",
            addr[0],                    // byte 0: family code
            addr[1], addr[2], addr[3],  // byte 1-3: serial number
            addr[4], addr[5], addr[6]); // byte 4-6: serial number
    setID(buff);
    // always calculate the crc8 and tack onto the end of the address
    // reminder the crc8 is of the first seven bytes
    //_addr[_crc_byte] = OneWire::crc8(_addr, _addr_len - 1);
  };

  uint8_t family() { return firstAddressByte(); };
  uint8_t crc() { return addr()[_crc_byte]; };
  boolean isPowered() { return _power; };
  void setReadingCmdAck(time_t latency, const char *cid = nullptr) {
    if (_reading != nullptr) {
      _reading->setCmdAck(latency, cid);
    }
  }
  Reading *reading() { return _reading; };

  bool isDS2406() { return (family() == _family_DS2406) ? true : false; };
  bool isDS2408() { return (family() == _family_DS2408) ? true : false; };

  static uint8_t *parseId(char *name) {
    static uint8_t addr[_addr_len] = {0x00};
    //                 00000000001111111
    //       byte num: 01234567890123456
    // format of name: ds/01020304050607
    //      total len: 18 bytes (id + string terminator)
    if ((name[0] == 'd') && (name[1] == 's') && (name[2] == '/') &&
        (name[_id_len - 1] == 0x00)) {
      for (uint8_t i = 3, j = 0; j < _addr_len; i = i + 2, j++) {
        char digit[3] = {name[i], name[i + 1], 0x00};
        char *end_ptr;
        unsigned long val = strtoul(digit, &end_ptr, 16); // convert from hex

        addr[j] = (uint8_t)val;
      }
    }

    // calculate the crc8 and store as the last byte of the address
    addr[_crc_byte] = OneWire::crc8(addr, 7);
    return addr;
  };

  // info / debugg functions
  void printReadMS(const char *func, uint8_t indent = 2) {
    mcrUtil::printDateTime(func);
    Serial.print(familyDesc());
    Serial.print(" ");
    Serial.print(id());
    Serial.print(" read took ");
    Serial.print(readMS());
    Serial.println("ms");
  }

  void printWriteMS(const char *func, uint8_t indent = 2) {
    mcrUtil::printDateTime(func);
    Serial.print(id());
    Serial.print(" write took ");
    Serial.print(writeMS());
    Serial.println("ms");
  }

  void printPresenceFailed(const char *func, uint8_t indent = 2) {
    mcrUtil::printDateTime(func);
    Serial.print("presence failure while trying to access ");
    Serial.println(familyDesc());
  }

  // static member function for validating an address (ROM) is validAddress
  static bool validAddress(uint8_t *addr) {
    bool rc = true;

    if (addr[_family_byte] == 0x00)
      rc = false;

    // reminder crc8 is only first seven bytes
    if (OneWire::crc8(addr, _addr_len - 2) != addr[_crc_byte])
      rc = false;

    return rc;
  };
};

typedef class dsDev dsDev_t;

#endif // __cplusplus
#endif // ds_dev_h
