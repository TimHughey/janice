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

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "../misc/util.hpp"
#include "id.hpp"

mcrDevID::mcrDevID(const char *id) { this->initAndCopy(id); };

const uint8_t mcrDevID::max_len() { return _max_len; };

// mcrDevID_t &mcrDevID::operator=(mcrDevID_t &dev_id) {
//   _id[0] = 0x00;
//   strncat(_id, dev_id._id, _max_len);
//   return *this;
// }

mcrDevID::operator char *() { return _id; };

bool mcrDevID::operator==(mcrDevID_t &rhs) {
  // logDateTime(__PRETTY_FUNCTION__);
  // log("comparing ");
  // log(_id);
  // log(" to ");
  // log(rhs._id);

  auto rc = false;
  if (strncmp(_id, rhs._id, _max_len) == 0) {
    rc = true;
  }

  // if (rc) {
  //   log(" true", true);
  // } else {
  //   log(" false", true);
  // }

  return rc;
}

bool mcrDevID::operator==(char *rhs) {
  auto rc = false;
  if (strncmp(_id, rhs, _max_len) == 0) {
    rc = true;
  }

  return rc;
};

mcrDevID_t &mcrDevID::operator=(const char *id) {
  initAndCopy(id);
  return *this;
};

void mcrDevID::initAndCopy(const char *id) {
  _id[0] = 0x00;
  strncat(_id, id, _max_len - 1);
}

const char *mcrDevID::asString() { return _id; }

void mcrDevID::debug(bool newline) {
  log("mcrDevID_t id: ");
  log(_id, newline);
}

#endif
