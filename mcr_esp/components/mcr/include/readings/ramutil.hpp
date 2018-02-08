/*
    ramutil.hpp - Master Control Remote Relative Humidity Reading
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

#ifndef ram_util_reading_h
#define ram_util_reading_h

#include <string>

#include <external/ArduinoJSON.h>
#include <sys/time.h>
#include <time.h>

#include "readings/reading.hpp"

typedef class ramUtilReading ramUtilReading_t;

class ramUtilReading : public Reading {
private:
  const uint32_t _max_ram = 520 * 1024;
  // actual reading data
  uint32_t _free_ram = 0;

public:
  // undefined reading
  ramUtilReading(uint32_t free_ram, time_t mtime = time(nullptr));
  uint32_t freeRAM() { return _free_ram; }

protected:
  virtual void populateJSON(JsonObject &root);
};

#endif // ram_util_reading_h
