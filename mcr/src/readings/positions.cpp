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
  if (pios < (_max_pios + 1)) {
    _pios = pios;
    _states = states;
  }
}

void positionsReading::populateJSON(JsonObject &root) {
  // DEPRECATED!!
  // must set aside enough memory for all generated pios because ArduinoJson
  // does not copy the source data and will reference it later when creating
  // the actual json
  // static char pio_id[_max_pios][2] = {0x00};

  root["type"] = "switch";
  root["pio_count"] = _pios;

  JsonArray &pio = root.createNestedArray("states");

  // here we have two loop variables
  // 1.  i -> counts the pios upwards
  // 2.  k -> used to access the state bits since the least significant
  //          bit is for pio 0
  for (uint8_t i = 0, k = _max_pios; i < _pios; i++, k--) {
    // char  pio_id[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    boolean pio_state = (_states & ((uint16_t)0x01 << i));
    JsonObject &item = pio.createNestedObject();

    item.set("pio", i);
    item.set("state", pio_state);

    // DEPRECATED!!
    // pio_id[i][0] = 'p';
    // itoa(i, &(pio_id[i][1]), 10);
    // item.set(&(pio_id[i][0]), pio_state);

    // #ifdef VERBOSE
    //     log(" pio=");
    //     log(&(pio_id[i][0]));
    //     log(",");
    //     log(pio_state);
    // #endif
  }
}

#endif // __cplusplus
