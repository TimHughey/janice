/*
    id.hpp - Master Control Remote Device ID
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

#include <FreeRTOS.h>
#include <System.h>
#include <sys/time.h>
#include <time.h>

#include "addr.hpp"
#include "id.hpp"
#include "util.hpp"

mcrDevID::mcrDevID(const char *id) { this->initAndCopy(id); };
mcrDevID::~mcrDevID() {
  if (_debug_str)
    delete _debug_str;
}

uint32_t mcrDevID::max_len() { return _max_len; };

// mcrDevID_t &mcrDevID::operator=(mcrDevID_t &dev_id) {
//   _id[0] = 0x00;
//   strncat(_id, dev_id._id, _max_len);
//   return *this;
// }

mcrDevID::operator char *() { return _id; };

bool mcrDevID::operator==(mcrDevID_t &rhs) {

  auto rc = false;
  if (strncmp(_id, rhs._id, _max_len) == 0) {
    rc = true;
  }

  return rc;
}

bool mcrDevID::operator==(char *rhs) {
  auto rc = false;
  if (strncmp(_id, rhs, _max_len) == 0) {
    rc = true;
  }

  return rc;
};

// mcrDevID_t &mcrDevID::operator=(const char *id) {
//   initAndCopy(id);
//   return *this;
// };

void mcrDevID::initAndCopy(const char *id) {
  _id[0] = 0x00;
  strncat(_id, id, _max_len);
}

bool mcrDevID::valid() { return _id[0] != 0x00; }

const char *mcrDevID::asString() { return _id; }

char *mcrDevID::debug() {
  const size_t buff_len = _max_len + 11;

  if (_debug_str == nullptr) {
    _debug_str = new char[buff_len + 1];
    bzero(_debug_str, buff_len);

    snprintf(_debug_str, buff_len, "mcrDevID(%s)", _id);
  }
  return _debug_str;
}

void mcrDevID::debug(char *buff, size_t len) {
  char *str = debug();

  strncat(buff, str, len);
}
