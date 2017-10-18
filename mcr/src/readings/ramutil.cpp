/*
    ramutil.cpp - Master Control Remote Relative Humidity Reading
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

#include "../include/mcr_dev.hpp"
#include "../include/mcr_util.hpp"
#include "../include/ramutil.hpp"
#include "../include/reading.hpp"

ramUtilReading::ramUtilReading(uint16_t free_ram, time_t mtime)
    : Reading(mtime) {
  _free_ram = free_ram;
}

void ramUtilReading::populateJSON(JsonObject &root) {
  root["type"] = "stats";
  root["freeram"] = _free_ram;
  root["maxram"] = _max_ram;
}

#endif // __cplusplus
