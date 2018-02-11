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
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <sstream>

#include <esp_log.h>
#include <sys/time.h>
#include <time.h>

#include "devs/addr.hpp"
#include "misc/util.hpp"

mcrDevAddr::mcrDevAddr(uint8_t addr) { _addr.push_back(addr); }
mcrDevAddr::mcrDevAddr(uint8_t *addr, uint32_t len) {
  _addr.reserve(len);
  std::copy(addr, addr + len, std::back_inserter(_addr));
  ESP_LOGW("mcrDevAddr", "%s", debug().c_str());
  // _addr.assign(len, *addr);
}

uint32_t mcrDevAddr::len() { return _addr.size(); }
uint8_t mcrDevAddr::firstAddressByte() { return _addr[0]; }
uint8_t mcrDevAddr::addressByteByIndex(uint32_t index) { return _addr[0]; }
uint32_t mcrDevAddr::max_len() { return _max_len; }

// support type casting from mcrDevID_t to a plain ole char array
mcrDevAddr::operator uint8_t *() { return _addr.data(); }

uint8_t mcrDevAddr::operator[](int i) { return _addr[i]; }

// NOTE:
//    1. the == ooperator will compare the actual addr and not the pointers
//    2. the lhs argument decides the length of address to compare
bool mcrDevAddr::operator==(const mcrDevAddr_t &rhs) {
  return (_addr == rhs._addr);
}

bool mcrDevAddr::isValid() { return !_addr.empty(); }

std::string mcrDevAddr::debug() {
  std::stringstream debug_str;

  debug_str << "mcrDevAddr(0x";
  for (auto it = _addr.begin(); it != _addr.end(); it++) {
    debug_str << std::setw(sizeof(uint8_t) * 2) << std::setfill('0') << std::hex
              << static_cast<uint8_t>(*it);
  };

  debug_str << ")";

  return debug_str.str();
}
