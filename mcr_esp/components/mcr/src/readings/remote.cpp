/*
    remote.cpp - Master Control Remote Reading
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

#include <esp_log.h>
#include <esp_system.h>
#include <esp_wifi.h>

#include "readings/remote.hpp"

namespace mcr {
remoteReading::remoteReading(uint32_t batt_mv)
    : Reading(time(nullptr)), batt_mv_(batt_mv) {

  _type = ReadingType_t::REMOTE;

  ap_rc_ = esp_wifi_sta_get_ap_info(&ap_);

  if (ap_rc_ != ESP_OK) {
    bzero(&ap_, sizeof(ap_));
  }

  heap_free_ = esp_get_free_heap_size();
  heap_min_ = esp_get_minimum_free_heap_size();
  uptime_us_ = esp_timer_get_time();
};

void remoteReading::populateJSON(JsonDocument &doc) {
  char bssid_str[] = "xx:xx:xx:xx:xx:xx";
  snprintf(bssid_str, sizeof(bssid_str), "%02x:%02x:%02x:%02x:%02x:%02x",
           ap_.bssid[0], ap_.bssid[1], ap_.bssid[2], ap_.bssid[3], ap_.bssid[4],
           ap_.bssid[5]);

  doc["bssid"] = bssid_str;
  doc["ap_rssi"] = ap_.rssi;
  doc["ap_pri_chan"] = ap_.primary;
  doc["batt_mv"] = batt_mv_;
  doc["heap_free"] = heap_free_;
  doc["heap_min"] = heap_min_;
  doc["uptime_us"] = uptime_us_;
};
} // namespace mcr
