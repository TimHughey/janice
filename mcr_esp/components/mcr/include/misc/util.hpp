/*
    util.hpp - Master Control Remote Utility Functions
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

#ifndef mcr_util_h
#define mcr_util_h

#include <string>

#include <sys/time.h>
#include <time.h>

#include "misc/mcr_types.hpp"

class mcrUtil {
public:
  static const char *dateTimeString(time_t t = 0);
  static int freeRAM();
  static const std::string &hostID();
  static const std::string &macAddress();
};

#endif // mcrUtil_hpp
