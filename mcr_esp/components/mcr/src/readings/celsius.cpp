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

#include "readings/celsius.hpp"

namespace mcr {

celsiusReading::celsiusReading(const std::string &id, time_t mtime,
                               float celsius)
    : Reading(id, mtime) {
  _celsius = celsius;

  // set the type of reading if it hasn't already been set
  // since this class can be subclassed
  _type = (_type == BASE) ? ReadingType_t::TEMP : _type;
};

void celsiusReading::populateJSON(JsonDocument &doc) {
  doc["tc"] = _celsius;
  doc["tf"] = _celsius * 1.8 + 32.0;
};
} // namespace mcr
