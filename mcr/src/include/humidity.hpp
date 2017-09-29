/*
    humidity.hpp - Master Control Remote Relative Humidity Reading
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

#ifndef humidity_reading_h
#define humidity_reading_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <TimeLib.h>

#include "celsius.hpp"
#include "dev_id.hpp"

typedef class humidityReading humidityReading_t;

class humidityReading : public celsiusReading {
private:
  // actual reading data
  float _relhum = 0.0;

public:
  // undefined reading
  humidityReading(mcrDevID_t &id, time_t mtime, float celsius, float relhum);

protected:
  void populateJSON(JsonObject &root);
};

#endif // __cplusplus
#endif // temp_reading_h
