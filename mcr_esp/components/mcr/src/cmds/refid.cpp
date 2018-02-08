/*
    refid.hpp - Master Control Remote Reference ID (aka UUID)
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
#include <esp_log.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/refid.hpp"

mcrRefID::mcrRefID(const char *id) { this->initAndCopy(id); };

uint32_t mcrRefID::max_len() { return _max_len; };

// mcrRefID_t &mcrRefID::operator=(mcrRefID_t &id) {
//   initAndCopy(id._id);
//   return *this;
// }

// type cast support from mcrRefID to char *
mcrRefID::operator char *() { return _id; };
mcrRefID::operator const char *() { return _id; };

// eqaulity operators returning true or false depending upon the embedded refid
bool mcrRefID::operator==(mcrRefID_t &rhs) {
  auto rc = false;
  if (strncmp(_id, rhs._id, _max_len) == 0) {
    rc = true;
  }

  return rc;
}

bool mcrRefID::operator==(char *rhs) {
  auto rc = false;
  if (strncmp(_id, rhs, _max_len) == 0) {
    rc = true;
  }

  return rc;
};

// assignment operator from a plain ole char *
// to a mcrRefID_t object reference
mcrRefID_t &mcrRefID::operator=(const char *id) {
  // logDateTime(__PRETTY_FUNCTION__);
  // log("copying ");
  // log(id);
  // log(" to this", true);
  this->initAndCopy(id);
  return *this;
};

void mcrRefID::initAndCopy(const char *id) {
  _id[0] = 0x00;

  if (id)
    strncat(_id, id, _max_len);
}

const char *mcrRefID::asString() { return _id; }
