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
#include <cstring>

#include <FreeRTOS.h>
#include <System.h>
#include <esp_wifi.h>
#include <sys/time.h>
#include <time.h>

#include "misc/util.hpp"

extern "C" {
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

char *mcrUtil::macAddress() {
  static char _mac[13] = {0x00};

  if (_mac[0] == 0x00) {
    uint8_t mac[6];

    esp_wifi_get_mac(WIFI_IF_STA, mac);

    sprintf(_mac, "%02x%02x%02x%02x%02x%02x", mac[5], mac[4], mac[3], mac[2],
            mac[1], mac[0]);
  }

  return _mac;
};

const char *mcrUtil::hostID() {
  static char _host_id[20] = {0x00};

  if (_host_id[0] == 0x00) {
    char *macAddress = mcrUtil::macAddress();

    sprintf(_host_id, "mcr.%s", macAddress);
  }

  return _host_id;
}

int mcrUtil::freeRAM() {
  System system;

  return system.getFreeHeapSize();
};

const char *mcrUtil::indentString(uint32_t indent) {
  const uint32_t max_indent = 25;
  static char indent_str[max_indent + 1] = {0x00}; // used for indenting

  indent = (indent < max_indent) ? indent : max_indent;

  memset(indent_str, 0x20, indent - 1);
  indent_str[indent] = 0x00;

  return indent_str;
}

void mcrUtil::printIndent(uint32_t indent) {
  // Serial.print(indentString(indent));
}

bool mcrUtil::isTimeByeondEpochYear() {
  time_t now = 0;
  struct tm timeinfo = {};

  time(&now);
  localtime_r(&now, &timeinfo);

  return (timeinfo.tm_year > 1971);
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
  // strftime(buf, buf_size, "%Y-%m-%d %H:%M:%S", &timeinfo);
  strftime(buf, buf_size, "%c", &timeinfo);

  return buf;
}
