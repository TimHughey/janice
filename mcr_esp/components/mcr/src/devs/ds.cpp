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

#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <esp_log.h>
#include <sys/time.h>
#include <time.h>

#include "addr.hpp"
#include "base.hpp"
#include "ds_dev.hpp"
#include "owb.h"
#include "refid.hpp"
#include "util.hpp"

dsDev::dsDev(mcrDevAddr_t &addr, bool power) : mcrDev(addr) {
  char buff[_id_len] = {0x00};
  // byte   0: 8-bit family code
  // byte 1-6: 48-bit unique serial number
  // byte   7: crc
  _power = power;

  setDescription(familyDescription());

  //                 00000000001111111
  //       byte num: 01234567890123456
  //     exmaple id: ds/28ffa442711604
  // format of name: ds/famil code + 48-bit serial (without the crc)
  //      total len: 18 bytes (id + string terminator)
  sprintf(buff, "ds/%02x%02x%02x%02x%02x%02x%02x",
          addr[0],                    // byte 0: family code
          addr[1], addr[2], addr[3],  // byte 1-3: serial number
          addr[4], addr[5], addr[6]); // byte 4-6: serial number

  const mcrDevID_t dev_id = mcrDevID(buff);
  setID(dev_id);
};

uint8_t dsDev::family() { return firstAddressByte(); };
uint8_t dsDev::crc() { return addr()[_crc_byte]; };
uint8_t dsDev::addrLen() { return _ds_max_addr_len; }
void dsDev::copyAddrToCmd(uint8_t *cmd) {
  memcpy(cmd + 1, addr(), _ds_max_addr_len);
}

bool dsDev::isPowered() { return _power; };
Reading_t *dsDev::reading() { return _reading; };

bool dsDev::isDS1820() {
  auto rc = false;

  switch (family()) {
  case 0x10:
  case 0x22:
  case 0x28:
    rc = true;
    break;
  default:
    rc = false;
  }

  return rc;
}
bool dsDev::isDS2406() { return (family() == _family_DS2406) ? true : false; };
bool dsDev::isDS2408() { return (family() == _family_DS2408) ? true : false; };
bool dsDev::hasTemperature() { return isDS1820(); }

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
    for (uint32_t i = 3, j = 0; j < _addr_len; i = i + 2, j++) {
      char digit[3] = {name[i], name[i + 1], 0x00};
      char *end_ptr;
      unsigned long val = strtoul(digit, &end_ptr, 16); // convert from hex

      addr[j] = (uint8_t)val;
    }
  }

  // calculate the crc8 and store as the last byte of the address
  addr[_crc_byte] = owb_crc8_bytes(0x00, (uint8_t *)addr, _addr_len - 2);
  return addr;
}

const std::string &dsDev::familyDescription() {
  return familyDescription(family());
}

const std::string &dsDev::familyDescription(uint8_t family) {
  static std::string desc;

  switch (family) {
  case 0x10:
  case 0x22:
  case 0x28:
    desc = std::string("ds1820");
    break;

  case 0x29:
    desc = std::string("ds2408");
    break;

  case 0x12:
    desc = std::string("ds2406");
    break;

  default:
    desc = std::string("dsUNDEF");
    break;
  }

  return desc;
};

void dsDev::logPresenceFailed() {
  ESP_LOGI("dsDev", "%s presence failure", familyDescription().c_str());
}

// static member function for validating an address (ROM) is validAddress
bool dsDev::validAddress(mcrDevAddr_t &addr) {
  bool rc = true;

  if (addr[_family_byte] == 0x00)
    rc = false;

  // reminder crc8 is only first seven bytes
  // owb_crc8_bytes returns 0x00 if last byte is CRC and there's a match
  if (owb_crc8_bytes(0x00, (uint8_t *)addr, _addr_len - 1) != 0x00) {
    rc = false;
  }

  return rc;
}

const std::string dsDev::debug() {
  std::ostringstream debug_str;

  debug_str << "dsDev(family=" << familyDescription().c_str() << " "
            << mcrDev::debug() << ")";

  return debug_str.str();
}
