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

#include <cstdlib>
#include <ctime>

#include <external/ArduinoJson.h>

#include "readings/startup_reading.hpp"

startupReading::startupReading(time_t mtime, const std::string &last_reboot)
    : Reading(mtime), last_reboot_m(last_reboot){};

void startupReading::populateJSON(JsonObject &root) {
  root["type"] = "boot";
  root["hw"] = "esp32";
  root["last_restart"] = last_reboot_m;
};
