/*
    remote_reading.hpp - Master Control Remote Celsius Reading
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

#ifndef remote_reading_hpp
#define remote_reading_hpp

#include <string>

#include <esp_system.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/id.hpp"
#include "readings/reading.hpp"

typedef class remoteReading remoteReading_t;

class remoteReading : public Reading {
private:
  wifi_ap_record_t ap_;
  esp_err_t ap_rc_;
  uint32_t batt_mv_;
  uint32_t heap_free_;
  uint32_t heap_min_;
  uint64_t uptime_us_;

protected:
  std::string type_;

public:
  remoteReading(uint32_t batt_mv);

protected:
  virtual void populateJSON(JsonDocument &doc);
};

#endif
