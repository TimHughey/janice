/*
    mcr_util.hpp - Master Control Remote Utility Functions
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

#ifndef mcr_util_h
#define mcr_util_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

#include "mcr_cmd.hpp"

extern "C" char *sbrk(int i);

#ifndef log
#define log mcrUtil::printLog
#define logDateTime mcrUtil::printDateTime
#define logElapsed mcrUtil::printElapsed
#define logElapsedMicros mcrUtil::printElapsedMicros
#endif

class mcrUtil {
public:
  static char *macAddress() {
    static char _mac[13] = {0x00};

    if (_mac[0] == 0x00) {
      byte mac[6];

      WiFi.macAddress(mac);

      sprintf(_mac, "%02x%02x%02x%02x%02x%02x", mac[5], mac[4], mac[3], mac[2],
              mac[1], mac[0]);
    }

    return _mac;
  };

  static const char *hostID() {
    static char _host_id[17] = {0x00};

    if (_host_id[0] == 0x00) {
      char *macAddress = mcrUtil::macAddress();

      sprintf(_host_id, "mcr.%s", macAddress);
    }

    return _host_id;
  }

  static int freeRAM() {
    char stack_dummy = 0;
    return &stack_dummy - sbrk(0);
  };

  static const char *indentString(uint8_t indent = 2) {
    static char indent_str[10] = {0x00}; // used for indenting

    if (indent > 9)
      indent = 9;

    for (uint8_t i = 0; i < indent; i++) {
      indent_str[i] = ' '; // this is just a space
    }
    indent_str[indent] = 0x00; // null terminate the string

    return indent_str;
  }

  static void printIndent(uint8_t indent = 2) {
    Serial.print(indentString(indent));
  }

  static bool isTimeByeondEpochYear() {
    return (now() > 365 * 60 * 60 * 60) ? true : false;
  }

  static const char *dateTimeString(time_t t = now()) {
    static char dt[30] = {0x00};

    if (mcrUtil::isTimeByeondEpochYear()) {
      t -= (4 * 60 * 60); // rough conversion to EDT

      sprintf(dt, "%02d/%02d/%02d %02d:%02d:%02d ", month(t), day(t), year(t),
              hour(t), minute(t), second(t));
    } else {
      sprintf(dt, "%16lu ms ", millis());
    }

    return dt;
  }

  static void printDateTime(time_t t = now()) {
    Serial.print(dateTimeString(t));
  }

  static void printElapsed(elapsedMillis e, bool newline = false) {
    const char *units = "ms";
    float val = e;

    if (e > 1000) {          // if needed, convert to secs for human
      val = (float)e / 1000; // readability.  yes, this is a bit much but
      units = "s";           // it's my software
    }

    Serial.print(val);
    Serial.print(units);

    if (newline)
      Serial.println();
  }

  static void printDateTime(const char *func) {
    printDateTime();
    printIndent();
    Serial.print(func);
    Serial.print(" ");
  }

  static void printNet(const char *func = NULL) {
    if (func)
      printDateTime(func);
    else
      printDateTime(__PRETTY_FUNCTION__);
    // print the SSID of the network you're attached to:
    Serial.print("SSID: ");
    Serial.print(WiFi.SSID());

    // print the MAC address of the router you're attached to:
    byte bssid[6];
    WiFi.BSSID(bssid);
    Serial.print("  BSSID: ");
    Serial.print(bssid[5], HEX);
    Serial.print(":");
    Serial.print(bssid[4], HEX);
    Serial.print(":");
    Serial.print(bssid[3], HEX);
    Serial.print(":");
    Serial.print(bssid[2], HEX);
    Serial.print(":");
    Serial.print(bssid[1], HEX);
    Serial.print(":");
    Serial.print(bssid[0], HEX);

    // print the received signal strength:
    long rssi = WiFi.RSSI();
    Serial.print("  RSSI: ");
    Serial.print(rssi);

    // print the encryption type:
    byte encryption = WiFi.encryptionType();
    Serial.print("  Encryption: ");
    Serial.print(encryption, HEX);

    IPAddress ip = WiFi.localIP();
    Serial.print("  IP: ");
    Serial.print(ip);

    Serial.print("  MAC: ");
    Serial.println(mcrUtil::macAddress());
  }

  static void printFreeMem(const char *func = NULL, uint8_t secs = 15) {
    static int first_free = 0;
    static int prev_free = 0;
    static elapsedMillis freeMemReport;
    int delta = prev_free - freeRAM();
    int delta_since_first = first_free - freeRAM();

    if (first_free == 0) {
      first_free = mcrUtil::freeRAM();
      delta_since_first = 0;
    }

    if (freeMemReport >= (secs * 1000)) {
      int percentFree = ((float)freeRAM() / (float)32000) * 100;
      int freeK = freeRAM() / 1000;

      if (func)
        printDateTime(func);
      else
        printDateTime(__PRETTY_FUNCTION__);

      Serial.print("free SRAM: ");
      Serial.print(percentFree);
      Serial.print("% (");
      Serial.print(freeK);
      Serial.print("k of 32k) delta: ");
      Serial.print(delta);
      Serial.print(" delta since first report: ");
      Serial.print(delta_since_first);
      Serial.println();

      freeMemReport = 0;
      prev_free = mcrUtil::freeRAM();
    }
  }

  static void printLog(const char *string, bool newline = false) {
    if (newline)
      Serial.println(string);
    else
      Serial.print(string);
  }

  static void printLog(int value, bool newline = false) {
    if (newline)
      Serial.println(value);
    else
      Serial.print(value);
  }

  static void printLog(mcrCmd_t &cmd, bool newline = false) {
    Serial.print("dev_id=");
    Serial.print(cmd.dev_id());
    Serial.print(" ");
    Serial.print("latency=");
    printElapsedMicros(cmd.latency());

    if (newline)
      Serial.println();
  }

  static void printElapsedMicros(elapsedMicros e, bool newline = false) {
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
};

#endif // __cplusplus
#endif // reading_h
