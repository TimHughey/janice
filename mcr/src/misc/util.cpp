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
#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

#include "util.hpp"

extern "C" char *sbrk(int i);

char *mcrUtil::macAddress() {
  static char _mac[13] = {0x00};

  if (_mac[0] == 0x00) {
    uint8_t mac[6];

    WiFi.macAddress(mac);

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
  char stack_dummy = 0;
  return &stack_dummy - sbrk(0);
};

const char *mcrUtil::indentString(uint8_t indent) {
  const uint8_t max_indent = 25;
  static char indent_str[max_indent + 1] = {0x00}; // used for indenting

  indent = (indent < max_indent) ? indent : max_indent;

  memset(indent_str, 0x20, indent);
  indent_str[indent + 1] = 0x00;

  return indent_str;
}

void mcrUtil::printIndent(uint8_t indent) {
  Serial.print(indentString(indent));
}

bool mcrUtil::isTimeByeondEpochYear() {
  return (now() > 365 * 60 * 60 * 60) ? true : false;
}

const char *mcrUtil::dateTimeString(time_t t) {
  static char dt[30] = {0x00};

  if (mcrUtil::isTimeByeondEpochYear()) {
    t -= (5 * 60 * 60); // rough conversion to ET

    // example: "01/01/17 00:00:00 "
    sprintf(dt, "%02d/%02d/%02d %02d:%02d:%02d ", month(t), day(t), year(t),
            hour(t), minute(t), second(t));
  } else {
    sprintf(dt, "%16lu ms ", millis());
  }

  return dt;
}

void mcrUtil::printDateTime(time_t t) { Serial.print(dateTimeString(t)); }

void mcrUtil::printElapsed(elapsedMillis e, bool newline) {
  const char *ms = "ms";
  const char *secs = "s";
  const char *units = ms;
  float val = e;

  if (e > 1000) {          // if needed, convert to secs for human
    val = (float)e / 1000; // readability.  yes, this is a bit much but
    units = secs;          // it's my software
  }

  Serial.print(val);
  Serial.print(units);

  if (newline)
    Serial.println();
}

void mcrUtil::printDateTime(const char *func) {
  printDateTime();
  printIndent();
  Serial.print(func);
  Serial.print(" ");
}

void mcrUtil::printNet(const char *func) {
  if (func)
    printDateTime(func);
  else
    printDateTime(__PRETTY_FUNCTION__);

  // print the SSID of the network you're attached to:
  log("SSID=");
  log(WiFi.SSID());

  // print the MAC address of the router you're attached to:
  uint8_t bssid[6];
  WiFi.BSSID(bssid);
  log(" BSSID=");
  logAsHexRaw(bssid[5]);
  log(":");
  logAsHexRaw(bssid[4]);
  log(":");
  logAsHexRaw(bssid[3]);
  log(":");
  logAsHexRaw(bssid[2]);
  log(":");
  logAsHexRaw(bssid[1]);
  log(":");
  logAsHexRaw(bssid[0]);

  // print the received signal strength:
  log(" RSSI=");
  log(WiFi.RSSI());

  // print the encryption type:
  byte encryption = WiFi.encryptionType();
  log(" Encryption: ");
  logAsHex(encryption);

  IPAddress ip = WiFi.localIP();

  if (func)
    printDateTime(func);
  else
    printDateTime(__PRETTY_FUNCTION__);

  log("IP=");
  log(ip);

  log(" MAC=");
  log(mcrUtil::macAddress(), true);
}

void mcrUtil::printFreeMem(const char *func, uint8_t secs) {
  static int first_free = 0;
  static int prev_free = 0;
  static int min_free = 0;
  static int max_free = 0;
  static elapsedMillis freeMemReport;
  int free_ram = freeRAM();
  int delta = (prev_free > 0) ? free_ram - prev_free : 0;

  if (first_free == 0) {
    first_free = free_ram;
  }

  if ((min_free == 0) || (max_free == 0)) {
    min_free = free_ram;
    max_free = free_ram;
  } else {
    if (free_ram > max_free)
      max_free = free_ram;

    if (free_ram < min_free)
      min_free = free_ram;
  }

  if (freeMemReport >= (secs * 1000)) {
    int percentFree = ((float)freeRAM() / (float)(32 * 1024)) * 100;
    int freeK = freeRAM() / 1024;

    if (delta != 0) {

      if (func)
        printDateTime(func);
      else
        printDateTime(__PRETTY_FUNCTION__);

      log("free SRAM: ");
      log(percentFree);
      log("% (");
      log(freeK);
      log("k of 32k) dif: ");
      log(delta);
      log(" min: ");
      log(min_free);
      log(" now: ");
      log(free_ram);
      log(" max: ");
      log(max_free, true);
    }

    freeMemReport = 0;
    prev_free = mcrUtil::freeRAM();
  }
}

void mcrUtil::printLog(const char *string, bool newline) {
  if (newline)
    Serial.println(string);
  else
    Serial.print(string);
}

void mcrUtil::printLog(int value, bool newline) {
  if (newline)
    Serial.println(value);
  else
    Serial.print(value);
}

void mcrUtil::printLogAsBinary(uint8_t value, bool newline) {
  Serial.print("0b");
  if (newline)
    Serial.println(value, BIN);
  else
    Serial.print(value, BIN);
}

void mcrUtil::printLogAsHex(uint8_t value, bool newline) {
  Serial.print("0x");
  if (newline)
    Serial.println(value, HEX);
  else
    Serial.print(value, HEX);
}

void mcrUtil::printLogAsHexRaw(uint8_t value, bool newline) {
  if (newline)
    Serial.println(value, HEX);
  else
    Serial.print(value, HEX);
}

void mcrUtil::printLogContinued() {
  Serial.print("\n");
  printIndent(24);
}

void mcrUtil::printElapsedMicros(elapsedMicros e, bool newline) {
  const char *units = "us";
  float val = e;

  if (e > 1000) {          // if needed, convert to ms for human
    val = (float)e / 1000; // readability.  yes, this is a bit much but
    units = "ms";          // it's my software
  }

  Serial.print(val);
  Serial.print(units);
  if (newline)
    Serial.println();
}

#endif // __cplusplus
