/*
    soil.hpp - Master Control Remote Soil Moisture Reading from Seesaw
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

#ifndef soil_seesaw_h
#define soil_seesaw_h

#include <string>

#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/id.hpp"
#include "readings/celsius.hpp"

namespace mcr {
typedef class soilReading soilReading_t;

class soilReading : public celsiusReading_t {
private:
  // actual reading data
  int _soil_moisture = 0;

public:
  // undefined reading
  // celsiusReading(){};
  soilReading(const mcrDevID_t &id, time_t mtime, float celsius,
              int soil_moisture);

protected:
  virtual void populateJSON(JsonDocument &doc);
};
} // namespace mcr

#endif // __cplusplus
