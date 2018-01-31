/*
    humidity.cpp - Master Control Remote Relative Humidity Reading
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

#include "../devs/id.hpp"
#include "celsius.hpp"
#include "humidity.hpp"

humidityReading::humidityReading(mcrDevID_t &id, time_t mtime, float celsius,
                                 float relhum)
    : celsiusReading(id, mtime, celsius) {
  _relhum = relhum;
}

void humidityReading::populateJSON(JsonObject &root) {
  celsiusReading::populateJSON(root); // subclassing not supported so
  root["type"] = "relhum";            // the type is set here without any
  root["rh"] = _relhum;               // checks
}

#endif // __cplusplus
