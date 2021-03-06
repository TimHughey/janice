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

#include <string>

#include <sys/time.h>
#include <time.h>

#include "readings/positions.hpp"

namespace mcr {
positionsReading::positionsReading(const std::string &id, time_t mtime,
                                   uint32_t states, uint32_t pios)
    : Reading(id, mtime) {

  _type = ReadingType_t::SWITCH;

  if (pios <= _max_pios) {
    _pios = pios;
    _states = states;
  }
}

void positionsReading::populateJSON(JsonDocument &doc) {
  doc["pio_count"] = _pios;

  JsonArray states = doc.createNestedArray("states");

  for (uint32_t i = 0; i < _pios; i++) {
    bool pio_state = (_states & (0x01 << i));
    JsonObject item = states.createNestedObject();

    item["pio"] = i;
    item["state"] = pio_state;
  }
}
} // namespace mcr
