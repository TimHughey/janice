/*
    celsius.cpp - Master Control Remote Celsius Reading
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

#include <string>

#include <sys/time.h>
#include <time.h>

#include "devs/id.hpp"
#include "readings/celsius.hpp"

celsiusReading::celsiusReading(const mcrDevID_t &id, time_t mtime,
                               float celsius)
    : Reading(id, mtime) {
  _celsius = celsius;
};

void celsiusReading::populateJSON(JsonObject &root) {
  if (!root.containsKey("type")) { // since this could be subclassed we
    root["type"] = "temp";         // need to check that the
  }                                // type hasn't been set
  root["tc"] = _celsius;
  root["tf"] = _celsius * 1.8 + 32.0;
};
