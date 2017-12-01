/*
    version.h - Master Control Remote Version
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

#ifndef version_h
#define version_h

#ifdef __cplusplus
#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

// below defines are used to stringify the value passed in as a define from
// the compiler cmd line
#define MCR_VERSION(s) (const char *)AS_STRING(s)
#define AS_STRING(s) #s

class Version {
private:
public:
  Version(){};
  static const char *string() {

#ifdef GIT_REV
    return MCR_VERSION(GIT_REV); // GIT_REV is set on compiler cmd line
#else
    return (const char *)"undef";
#endif
  }
};

#endif // __cplusplus
#endif // version_h
