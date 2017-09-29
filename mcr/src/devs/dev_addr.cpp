/*
    dev_id.cpp - Master Control Remote Address of Device
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

#include "../include/dev_addr.hpp"

// construct a very simple device address of only one byte
mcrDevAddr::mcrDevAddr(uint8_t addr) { _addr[0] = addr, _len = 1; }
// construct a slightly more complex device of a multi byte address
mcrDevAddr::mcrDevAddr(uint8_t *addr, uint8_t len) { initAndCopy(addr, len); }

uint8_t mcrDevAddr::len() { return _len; }
uint8_t mcrDevAddr::firstAddressByte() { return _addr[0]; }
uint8_t mcrDevAddr::addressByteByIndex(uint8_t index) { return _addr[0]; }
const uint8_t mcrDevAddr::max_len() { return _max_len; }

// support type casting from mcrDevID_t to a plain ole char array
mcrDevAddr::operator uint8_t *() { return _addr; }

uint8_t mcrDevAddr::operator[](int i) { return _addr[i]; }

// NOTE:
//    1. the == ooperator will compare the actual addr and not the pointers
//    2. the lhs argument decides the length of address to compare
bool mcrDevAddr::operator==(const mcrDevAddr_t &rhs) {
  auto rc = false;
  if (memcmp(_addr, rhs._addr, _len) == 0) {
    rc = true;
  }

  return rc;
}

// allow comparsions of a mcrDeviID to a plain ole char string array
bool mcrDevAddr::operator==(uint8_t *rhs) {
  auto rc = false;
  if (memcmp(_addr, rhs, _len) == 0) {
    rc = true;
  }

  return rc;
};

void mcrDevAddr::initAndCopy(uint8_t *addr, uint8_t len) {
  memset(_addr, 0x00, _max_len);
  memcpy(_addr, addr, len);
  _len = len;
}

#endif // __cplusplus
