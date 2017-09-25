/*
    dev_id.hpp - Master Control Remote Device ID
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

#ifndef dev_id_hpp
#define dev_id_hpp

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

typedef class mcrDevID mcrDevID_t;

class mcrDevID {
private:
  static const uint8_t _max_len = 30;
  char _id[_max_len] = {0x00};

public:
  mcrDevID(){};
  mcrDevID(const char *id) { this->initAndCopy(id); };

  static const uint8_t max_len() { return _max_len; };

  // support type casting from mcrDevID_t to a plain ole char array
  operator char *() { return _id; };

  // NOTE:  the == ooperator will compare the actual id and not the pointers
  bool operator==(mcrDevID_t &rhs) {
    auto rc = false;
    if (strncmp(_id, rhs._id, _max_len) == 0) {
      rc = true;
    }

    return rc;
  }

  // allow comparsions of a mcrDeviID to a plain ole char string array
  bool operator==(char *rhs) {
    auto rc = false;
    if (strncmp(_id, rhs, _max_len) == 0) {
      rc = true;
    }

    return rc;
  };

  mcrDevID_t &operator=(mcrDevID_t dev_id) {
    _id[0] = 0x00;
    strncat(_id, dev_id._id, _max_len);
    return *this;
  }

  mcrDevID_t &operator=(const char *id) {
    this->initAndCopy(id);
    return *this;
  };

  char *asString() { return _id; }

  static const int max_id_len = _max_len;

private:
  void initAndCopy(const char *id) {
    _id[0] = 0x00;
    strncat(_id, id, _max_len - 1);
  }
};

#endif // __cplusplus
#endif // mcrDev_h
