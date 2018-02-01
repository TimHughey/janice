/*
    refid.hpp - Master Control Remote Ref ID (aka UUID)
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

#ifndef ref_id_hpp
#define ref_id_hpp

#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <sys/time.h>
#include <time.h>

typedef class mcrRefID mcrRefID_t;

class mcrRefID {
private:
  static const uint32_t _max_len = 39;
  char _id[_max_len + 1] = {0x00}; // +1 for null terminating byte

public:
  static const int max_id_len = _max_len;

  mcrRefID(){};
  mcrRefID(const char *id);

  static uint32_t max_len();

  // support type casting to a plain ole char array
  operator char *();
  operator const char *();

  // NOTE:  the == ooperator will compare the actual id and not the pointers
  bool operator==(mcrRefID_t &rhs);

  // allow comparsions of an id to a plain ole char string array
  bool operator==(char *rhs);

  // assignment operators
  // mcrRefID_t &operator=(mcrRefID_t &id);
  // mcrRefID_t &operator=(mcrRefID_t *id);
  mcrRefID_t &operator=(const char *id);

  const char *asString();

private:
  void initAndCopy(const char *id);
};

#endif // mcrDev_h
