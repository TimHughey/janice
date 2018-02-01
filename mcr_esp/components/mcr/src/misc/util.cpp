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

#include "util.hpp"

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
//
// void mcrUtil::printDateTime(time_t t) { // Serial.print(dateTimeString(t));
// }
//
// void mcrUtil::printElapsed(time_t e, bool newline) {
//   const char *ms = "ms";
//   const char *secs = "s";
//   const char *units = ms;
//   float val = e;
//
//   if (e > 1000) {          // if needed, convert to secs for human
//     val = (float)e / 1000; // readability.  yes, this is a bit much but
//     units = secs;          // it's my software
//   }
//
//   // Serial.print(val);
//   // Serial.print(units);
//   //
//   // if (newline)
//   //   Serial.println();
// }
//
// void mcrUtil::printDateTime(const char *func) {
//   printDateTime();
//   printIndent();
//   // Serial.print(func);
//   // Serial.print(" ");
// }
//
// void mcrUtil::printNet(const char *func) {
//   if (func)
//     printDateTime(func);
//   else
//     printDateTime(__PRETTY_FUNCTION__);
//
//   // print the SSID of the network you're attached to:
//   log("ssid: ");
//   // log(WiFi.SSID());
//
//   // print the MAC address of the router you're attached to:
//   byte bssid[6] = {0x00};
//   // WiFi.BSSID(bssid);
//   log(" bssid: ");
//   logAsHexRaw(bssid[5]);
//   log(":");
//   logAsHexRaw(bssid[4]);
//   log(":");
//   logAsHexRaw(bssid[3]);
//   log(":");
//   logAsHexRaw(bssid[2]);
//   log(":");
//   logAsHexRaw(bssid[1]);
//   log(":");
//   logAsHexRaw(bssid[0]);
//
//   // print the received signal strength:
//   log(" rssi: ");
//   // log(WiFi.RSSI());
//
//   // print the encryption type:
//   // byte encryption = WiFi.encryptionType();
//   log(" encryption: ");
//   logAsHex(encryption, true);
//
//   if (func)
//     printDateTime(func);
//   else
//     printDateTime(__PRETTY_FUNCTION__);
//
//   // IPAddress ip = WiFi.localIP();
//   // log("ip: ");
//   // log(ip[0]);
//   // log(".");
//   // log(ip[1]);
//   // log(".");
//   // log(ip[2]);
//   // log(".");
//   // log(ip[3]);
//
//   log(" mac: ");
//   log(mcrUtil::macAddress(), true);
// }
//
// void mcrUtil::printFreeMem(const char *func, uint32_t secs) {
//   static int first_free = 0;
//   static int prev_free = 0;
//   static int min_free = 0;
//   static int max_free = 0;
//   static time_t freeMemReport;
//   int free_ram = freeRAM();
//   int delta = (prev_free > 0) ? free_ram - prev_free : 0;
//
//   if (first_free == 0) {
//     first_free = free_ram;
//   }
//
//   if ((min_free == 0) || (max_free == 0)) {
//     min_free = free_ram;
//     max_free = free_ram;
//   } else {
//     if (free_ram > max_free)
//       max_free = free_ram;
//
//     if (free_ram < min_free)
//       min_free = free_ram;
//   }
//
//   if (freeMemReport >= (secs * 1000)) {
//     int percentFree = ((float)freeRAM() / (float)(32 * 1024)) * 100;
//     int freeK = freeRAM() / 1024;
//
//     if (delta != 0) {
//
//       if (func)
//         printDateTime(func);
//       else
//         printDateTime(__PRETTY_FUNCTION__);
//
//       // log("free SRAM: ");
//       // log(percentFree);
//       // log("% (");
//       // log(freeK);
//       // log("k of 32k) dif: ");
//       // log(delta);
//       // log(" min: ");
//       // log(min_free);
//       // log(" now: ");
//       // log(free_ram);
//       // log(" max: ");
//       // log(max_free, true);
//     }
//
//     freeMemReport = 0;
//     prev_free = mcrUtil::freeRAM();
//   }
// }
//
// void mcrUtil::printLog(const char *string, bool newline) {
//   // if (newline)
//   //   Serial.println(string);
//   // else
//   //   Serial.print(string);
// }
//
// void mcrUtil::printLog(int value, bool newline) {
//   // if (newline)
//   //   Serial.println(value);
//   // else
//   //   Serial.print(value);
// }
//
// void mcrUtil::printLogAsBinary(uint32_t value, bool newline) {
//   // Serial.print("0b");
//   // if (newline)
//   //   Serial.println(value, BIN);
//   // else
//   //   Serial.print(value, BIN);
// }
//
// void mcrUtil::printLogAsHex(uint32_t value, bool newline) {
//   // Serial.print("0x");
//   // if (newline)
//   //   Serial.println(value, HEX);
//   // else
//   //   Serial.print(value, HEX);
// }
//
// void mcrUtil::printLogAsHexRaw(uint32_t value, bool newline) {
//   // if (newline)
//   //   Serial.println(value, HEX);
//   // else
//   //   Serial.print(value, HEX);
// }
//
// void mcrUtil::printLogContinued() {
//   // Serial.print("\n");
//   // printIndent(24);
// }
//
// void mcrUtil::printElapsedMicros(elapsedMicros e, bool newline) {
//   const char *units = "us";
//   float val = e;
//
//   if (e > 1000) {          // if needed, convert to ms for human
//     val = (float)e / 1000; // readability.  yes, this is a bit much but
//     units = "ms";          // it's my software
//   }
//
//   // Serial.print(val);
//   // Serial.print(units);
//   // if (newline)
//   //   Serial.println();
// }
