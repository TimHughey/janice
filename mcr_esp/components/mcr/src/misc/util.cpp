/*
    mcr_util.cpp - Master Control Remote Utility Functions
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
#include <iomanip>
#include <sstream>
#include <string>

#include <esp_heap_caps.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "misc/util.hpp"

extern "C" {
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

const char *mcrUtil::dateTimeString(time_t t) {
  static char buf[64] = {0x00};
  const auto buf_size = sizeof(buf);
  time_t now;
  struct tm timeinfo = {};

  time(&now);
  // Set timezone to Eastern Standard Time and print local time
  setenv("TZ", "EST5EDT,M3.2.0/2,M11.1.0", 1);
  tzset();
  localtime_r(&now, &timeinfo);

  strftime(buf, buf_size, "%c", &timeinfo);

  return buf;
}

int mcrUtil::freeRAM() { return heap_caps_get_free_size(MALLOC_CAP_8BIT); };

const std::string &mcrUtil::hostID() {
  static std::string _host_id;

  if (_host_id.length() == 0) {
    _host_id = "mcr.";
    _host_id += mcrUtil::macAddress();
  }

  return _host_id;
}

const std::string &mcrUtil::macAddress() {
  static std::string _mac;

  if (_mac.length() == 0) {
    std::stringstream bytes;
    uint8_t mac[6];

    esp_wifi_get_mac(WIFI_IF_STA, mac);

    bytes << std::hex << std::setfill('0');
    for (int i = 5; i >= 0; i--) {
      bytes << std::setw(sizeof(uint8_t) * 2) << static_cast<unsigned>(mac[i]);
    }

    _mac = bytes.str();
  }

  return _mac;
};
