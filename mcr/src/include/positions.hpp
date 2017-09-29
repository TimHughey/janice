/*
    positions.hpp - Master Control Remote Relative Humidity Reading
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

#ifndef positions_reading_h
#define positions_reading_h

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

#include "dev_id.hpp"
#include "reading.hpp"

typedef class positionsReading positionsReading_t;

class positionsReading : public Reading {
private:
  static const uint16_t _max_pios = 16;
  // actual reading data
  uint8_t _pios = 0;
  uint16_t _states = 0x0000;

public:
  // undefined reading
  positionsReading(mcrDevID_t &id, time_t mtime, uint16_t states, uint8_t pios);
  uint16_t state() { return _states; }

protected:
  virtual void populateJSON(JsonObject &root);
};

#endif // __cplusplus
#endif // positions_reading_h
