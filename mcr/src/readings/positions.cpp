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

positionsReading::positionsReading(mcrDevID_t &id, time_t mtime,
                                   uint16_t states, uint8_t pios)
    : Reading(id, mtime) {
  if (pios <= _max_pios) {
    _pios = pios;
    _states = states;
  }
}

void positionsReading::populateJSON(JsonObject &root) {
  root["type"] = "switch";
  root["pio_count"] = _pios;

  JsonArray &pio = root.createNestedArray("states");

  for (uint8_t i = 0; i < _pios; i++) {
    bool pio_state = (_states & ((uint16_t)0x01 << i));
    JsonObject &item = pio.createNestedObject();

    item.set("pio", i);
    item.set("state", pio_state);
  }
}

#endif // __cplusplus
