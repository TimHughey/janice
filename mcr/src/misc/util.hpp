/*
    util.hpp - Master Control Remote Utility Functions
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

#ifndef log
#define log mcrUtil::printLog
#define logDateTime mcrUtil::printDateTime
#define logElapsed mcrUtil::printElapsed
#define logElapsedMicros mcrUtil::printElapsedMicros
#endif

extern "C" char *sbrk(int i);

class mcrUtil {
public:
  static char *macAddress();
  static const char *hostID();

  static int freeRAM();

  static const char *indentString(uint8_t indent = 2);
  static void printIndent(uint8_t indent = 2);
  static bool isTimeByeondEpochYear();
  static const char *dateTimeString(time_t t = now());

  static void printDateTime(time_t t = now());
  static void printElapsed(elapsedMillis e, bool newline = false);
  static void printDateTime(const char *func);
  static void printNet(const char *func = nullptr);
  static void printFreeMem(const char *func = nullptr, uint8_t secs = 15);
  static void printLog(const char *string, bool newline = false);
  static void printLog(int value, bool newline = false);
  static void printElapsedMicros(elapsedMicros e, bool newline = false);
};

#endif // __cplusplus
#endif // reading_h
