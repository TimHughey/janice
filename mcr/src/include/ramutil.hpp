/*
    ramutil.hpp - Master Control Remote Relative Humidity Reading
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

#ifndef ram_util_reading_h
#define ram_util_reading_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

#include "reading.hpp"

typedef class ramUtilReading ramUtilReading_t;

class ramUtilReading : public Reading {
private:
  static const uint16_t _max_ram = 32 * 1024;
  // actual reading data
  uint16_t _free_ram = 0;

public:
  // undefined reading
  ramUtilReading(uint16_t free_ram, time_t mtime = now());
  uint16_t freeRAM() { return _free_ram; }

protected:
  virtual void populateJSON(JsonObject &root);
};

#endif // __cplusplus
#endif // ram_util_reading_h
