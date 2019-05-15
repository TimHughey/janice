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
#include <string>

#include <sys/time.h>
#include <time.h>

#include "protocols/mqtt.hpp"
#include "readings/ramutil.hpp"

namespace mcr {

ramUtilReading::ramUtilReading() {
  _type = ReadingType_t::RAM;
  refresh();
}

ramUtilReading::ramUtilReading(uint32_t free_ram, time_t mtime)
    : Reading(mtime), _free_ram(free_ram) {
  _type = ReadingType_t::RAM;
}

void ramUtilReading::populateJSON(JsonDocument &doc) {
  doc["freeram"] = _free_ram;
  doc["maxram"] = _max_ram;
}

void ramUtilReading::publish() {
  refresh();
  mcrMQTT_t *mqtt = mcrMQTT::instance();
  mqtt->publish(this);
}

void ramUtilReading::refresh() {
  Reading::refresh();
  _free_ram = heap_caps_get_free_size(MALLOC_CAP_8BIT);
}
} // namespace mcr
