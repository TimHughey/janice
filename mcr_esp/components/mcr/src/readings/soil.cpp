/*
    celsius.cpp - Master Control Remote Seesaw Soil Reading
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
#include "readings/soil.hpp"

soilReading::soilReading(const mcrDevID_t &id, time_t mtime, float celsius,
                         int soil_moisture)
    : celsiusReading(id, mtime, celsius) {
  _soil_moisture = soil_moisture;
};

void soilReading::populateJSON(JsonObject &root) {
  // the reading is:
  //  1. capacitive reading of soil moisture
  //  2. celsius temperature of the probe

  celsiusReading::populateJSON(root);

  // override the reading type from the base class
  root["type"] = "soil";
  root["cap"] = _soil_moisture;
};
