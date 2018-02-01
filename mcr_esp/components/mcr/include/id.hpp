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

#ifndef dev_id_hpp
#define dev_id_hpp

#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <sys/time.h>
#include <time.h>

typedef class mcrDevID mcrDevID_t;

class mcrDevID {
private:
  static const uint32_t _max_len = 30;
  char _id[_max_len + 1] = {0x00}; // +1 for null terminating byte

  char *_debug_str = nullptr;

public:
  static const int max_id_len = _max_len;

  mcrDevID(){};
  mcrDevID(const char *id);
  ~mcrDevID();

  static uint32_t max_len();

  // support type casting from mcrDevID_t to a plain ole char array
  operator char *();

  // NOTE:  the == ooperator will compare the actual id and not the pointers
  bool operator==(mcrDevID_t &rhs);

  // allow comparsions of a mcrDeviID to a plain ole char string array
  bool operator==(char *rhs);

  // copy constructor
  // mcrDevID_t &operator=(mcrDevID_t dev_id);
  // mcrDevID_t &operator=(const char *id);

  bool valid();

  const char *asString();
  char *debug();
  void debug(char *buff, size_t);

private:
  void initAndCopy(const char *id);
};

#endif // mcrDev_h
