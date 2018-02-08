/*
    id.hpp - Master Control Remote Address of Device
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

#ifndef dev_addr_hpp
#define dev_addr_hpp

#include <sstream>
#include <string>
#include <sys/time.h>
#include <time.h>

typedef class mcrDevAddr mcrDevAddr_t;

class mcrDevAddr {
private:
  static const uint32_t _max_len = 10;
  uint8_t _addr[_max_len + 1] = {0x00};
  uint8_t _len = 0;

  void initAndCopy(uint8_t *addr, uint32_t len);

public:
  static const int max_addr_len = _max_len;
  mcrDevAddr(){};
  // construct a very simple device address of only one byte
  mcrDevAddr(uint8_t addr);
  // construct a slightly more complex device of a multi byte address
  mcrDevAddr(uint8_t *addr, uint32_t len);

  uint32_t len();
  uint8_t firstAddressByte();
  uint8_t addressByteByIndex(uint32_t index);
  uint32_t max_len();
  bool isValid();

  // support type casting from mcrDevID_t to a plain ole uint8_t array
  operator uint8_t *();

  uint8_t operator[](int i);

  // NOTE:
  //    1. the == ooperator will compare the actual addr and not the pointers
  //    2. the lhs argument decides the length of address to compare
  bool operator==(const mcrDevAddr_t &rhs);

  // allow comparsions of a mcrDeviID to a plain ole char string array
  bool operator==(uint8_t *rhs);

  std::string debug();

private:
};

#endif // dev_addr_hpp
