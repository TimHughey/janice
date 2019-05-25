/*
    reading.h - Readings used within Master Control Remote
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

#ifndef reading_h
#define reading_h

// #include <memory>
#include <string>

#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "misc/mcr_types.hpp"

// Possible future improvement
// typedef std::unique_ptr<std::string> myString;

namespace mcr {
typedef enum {
  BASE = 0,
  ENGINE,
  PH,
  RAM,
  REMOTE,
  RELHUM,
  SOIL,
  STARTUP,
  SWITCH,
  TEMP,
  TEXT
} ReadingType_t;

typedef class Reading Reading_t;
typedef std::unique_ptr<Reading_t> Reading_ptr_t;

class Reading {
private:
  // reading metadata (id, measured time and type)
  std::string _id;
  time_t _mtime = time(nullptr); // time the reading was measureed

  // tracking info
  mcrRefID_t _refid;
  bool _cmd_ack = false;
  time_t _latency = 0;
  bool _mcp_log_reading = false;

  int64_t _read_us = 0;
  int64_t _write_us = 0;
  int _crc_mismatches = 0;
  int _read_errors = 0;
  int _write_errors = 0;

  char *_json = nullptr;

protected:
  ReadingType_t _type = BASE;

  void commonJSON(JsonDocument &doc);
  virtual void populateJSON(JsonDocument &doc){};

public:
  // default constructor, Reading type undefined
  Reading(){};
  Reading(const std::string &id, time_t mtime = time(nullptr));
  Reading(time_t mtime);
  virtual ~Reading();

  std::string *json(char *buffer = nullptr, size_t len = 0);
  virtual void publish();
  virtual void refresh() { time(&_mtime); }
  void setCmdAck(time_t latency, mcrRefID_t &refid);

  void setCRCMismatches(int crc_mismatches) {
    _crc_mismatches = crc_mismatches;
  }

  void setLogReading() { _mcp_log_reading = true; }
  void setReadErrors(int read_errors) { _read_errors = read_errors; }
  void setReadUS(int64_t read_us) { _read_us = read_us; }
  void setWriteErrors(int write_errors) { _write_errors = write_errors; }
  void setWriteUS(int64_t write_us) { _write_us = write_us; }

  static const char *typeString(ReadingType_t index);
};
} // namespace mcr

#endif // reading_h
