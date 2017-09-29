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

#include "../include/dev_id.hpp"
#include "../include/positions.hpp"
#include "../include/reading.hpp"

positionsReading::positionsReading(mcrDevID_t &id, time_t mtime, uint8_t pios,
                                   uint16_t states)
    : Reading(id, mtime) {
  if (pios < (_max_pios + 1)) {
    _pios = pios;
    _states = states;
  }
}

void positionsReading::populateJSON(JsonObject &root) {
  static char pio_id[_max_pios][2] = {0x00};

  root["type"] = "switch";
  root["pios"] = _pios;

  JsonArray &pio = root.createNestedArray("pio");

  for (uint8_t i = 0, k = _max_pios; i < _pios; i++, k--) {
    // char  pio_id[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    boolean pio_state = (_states & ((uint16_t)0x01 << i));
    JsonObject &item = pio.createNestedObject();

    itoa(i, &(pio_id[i][0]), 10);
    item.set(&(pio_id[i][0]), pio_state);
#ifdef VERBOSE
    log(" pio=");
    log(&(pio_id[i][0]));
    log(",");
    log(pio_state);
#endif
  }
}

#endif // __cplusplus
