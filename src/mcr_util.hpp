/*
    reading.h - Readings used within Master Control Remote
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

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

extern "C" char *sbrk(int i);

class mcrUtil {
public:
  static char *macAddress() {
    static char _mac[13] = {0x00};

    if (_mac[0] == 0x00) {
      byte mac[6];

      WiFi.macAddress(mac);

      sprintf(_mac, "%02x%02x%02x%02x%02x%02x", mac[5], mac[4], mac[3], mac[2],
              mac[1], mac[0]);
    }

    return _mac;
  };

  static const char *hostID() {
    static char _host_id[17] = {0x00};

    if (_host_id[0] == 0x00) {
      char *macAddress = mcrUtil::macAddress();

      sprintf(_host_id, "mcr.%s", macAddress);
    }

    return _host_id;
  }

  static int freeRAM() {
    char stack_dummy = 0;
    return &stack_dummy - sbrk(0);
  };

  static const char *indentString(uint8_t indent = 2) {
    static char indent_str[10] = {0x00}; // used for indenting

    if (indent > 9)
      indent = 9;

    for (uint8_t i = 0; i < indent; i++) {
      indent_str[i] = ' '; // this is just a space
    }
    indent_str[indent] = 0x00; // null terminate the string

    return indent_str;
  }
};

#endif // __cplusplus
#endif // reading_h
