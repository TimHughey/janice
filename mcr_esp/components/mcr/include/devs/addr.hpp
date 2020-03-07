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

#include <memory>
#include <string>
#include <vector>

using std::unique_ptr;

namespace mcr {

typedef class mcrDevAddr mcrDevAddr_t;

class mcrDevAddr {
private:
  static const uint32_t _max_len = 10;
  std::vector<uint8_t> _addr;

public:
  static const int max_addr_len = _max_len;
  mcrDevAddr(){};
  // construct a very simple device address of only one byte
  mcrDevAddr(uint8_t addr);
  // construct a slightly more complex device of a multi byte address
  mcrDevAddr(uint8_t *addr, uint32_t len);

  uint32_t len() const;
  uint8_t firstAddressByte() const;
  // uint8_t addressByteByIndex(uint32_t index);
  uint8_t lastAddressByte() const;
  uint32_t max_len() const;
  bool isValid() const;

  // support type casting from mcrDevAddr to a plain ole uint8_t array
  operator uint8_t *();

  uint8_t operator[](int i);

  bool operator==(const mcrDevAddr_t &rhs);

  const unique_ptr<char[]> debug();

private:
};
} // namespace mcr

#endif // dev_addr_hpp
