/*
    ds_dev.cpp - Master Control Dalla Semiconductor Device
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

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <OneWire.h>

#include "../misc/refid.hpp"
#include "../misc/util.hpp"
#include "addr.hpp"
#include "base.hpp"
#include "ds.hpp"

dsDev::dsDev(mcrDevAddr_t &addr, bool power) : mcrDev(addr) {
  char buff[_id_len] = {0x00};
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

  mcrDevID_t dev_id = mcrDevID(buff);
  setID(dev_id);
  // always calculate the crc8 and tack onto the end of the address
  // reminder the crc8 is of the first seven bytes
  //_addr[_crc_byte] = OneWire::crc8(_addr, _addr_len - 1);
};

uint8_t dsDev::family() { return firstAddressByte(); };
uint8_t dsDev::crc() { return addr()[_crc_byte]; };
bool dsDev::isPowered() { return _power; };
Reading_t *dsDev::reading() { return _reading; };

bool dsDev::isDS2406() { return (family() == _family_DS2406) ? true : false; };
bool dsDev::isDS2408() { return (family() == _family_DS2408) ? true : false; };

void dsDev::setReadingCmdAck(time_t latency, mcrRefID_t &refid) {
  if (_reading != nullptr) {
    _reading->setCmdAck(latency, refid);
  }
}

uint8_t *dsDev::parseId(char *name) {
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
}

const char *dsDev::familyDesc() { return familyDesc(family()); }
const char *dsDev::familyDesc(uint8_t family) {
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

// info / debugg functions
void dsDev::printReadMS(const char *func, uint8_t indent) {
  mcrUtil::printDateTime(func);
  Serial.print(familyDesc());
  Serial.print(" ");
  Serial.print(id());
  Serial.print(" read took ");
  Serial.print(readMS());
  Serial.println("ms");
}

void dsDev::printWriteMS(const char *func, uint8_t indent) {
  mcrUtil::printDateTime(func);
  Serial.print(id());
  Serial.print(" write took ");
  Serial.print(writeMS());
  Serial.println("ms");
}

void dsDev::logPresenceFailed(const char *func, uint8_t indent) {
  logDateTime(func);
  log("presence failure while trying to access ");
  log(familyDesc(), true);
}

// static member function for validating an address (ROM) is validAddress
bool dsDev::validAddress(mcrDevAddr_t *addr) {
  bool rc = true;

  if (addr[_family_byte] == 0x00)
    rc = false;

  // reminder crc8 is only first seven bytes
  uint8_t crc = addr->addressByteByIndex(_crc_byte);
  if (OneWire::crc8((uint8_t *)addr, _addr_len - 2) != crc)
    rc = false;

  return rc;
}

void dsDev::debug(bool newline) {
  log("dsDev_t id: ");
  log(id(), newline);
  // log(" ");
  // addr().debug(newline);
}

#endif
