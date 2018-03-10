/*
    celsius.hpp - Master Control Remote Celsius Reading
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

#ifndef startup_reading_hpp
#define startup_reading_hpp

#include <string>

#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/id.hpp"
#include "readings/reading.hpp"

typedef class startupReading startupReading_t;

class startupReading : public Reading {
private:
  std::string last_reboot_m;

public:
  startupReading(time_t mtime, const std::string &last_reboot);

protected:
  virtual void populateJSON(JsonObject &root);
};

#endif // startup_reading_hpp
